{
  lib,
  nixpkgs,
  system,
  self,
}:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowBroken = true;
  };

  availableHosts = builtins.attrNames (self.nixosConfigurations or {});

  hostnameSelector = pkgs.writeShellScriptBin "select-hostname" ''
    #!${pkgs.bash}/bin/bash
    set -e

    HOSTS="${lib.concatStringsSep " " availableHosts}"

    if [ -z "$HOSTS" ]; then
      echo "Error: No hosts defined in flake!"
      exit 1
    fi

    echo "Available hosts:"
    echo ""
    i=1
    for host in $HOSTS; do
      echo "  $i) $host"
      i=$((i + 1))
    done
    echo ""

    while true; do
      read -p "Select host to install [1-$#]: " choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $# ]; then
        selected_host=$(echo $HOSTS | cut -d' ' -f$choice)
        echo "Selected: $selected_host"
        echo "$selected_host" > /tmp/selected-hostname
        exit 0
      fi
      echo "Invalid selection. Please enter a number between 1 and $#."
    done
  '';

  flakeInstaller = pkgs.writeShellScriptBin "install-from-flake" ''
    #!${pkgs.bash}/bin/bash
    set -e

    FLAKE_URL="''${1:-github:flakesonnix/homelab}"
    SELECTED_HOSTNAME=$(cat /tmp/selected-hostname 2>/dev/null || echo "nixos")

    echo "Installing NixOS from flake: $FLAKE_URL#$SELECTED_HOSTNAME"

    if ! mountpoint -q /mnt; then
      echo "Error: /mnt is not mounted. Please partition and mount your disk first using Calamares."
      exit 1
    fi

    nixos-install --flake "$FLAKE_URL#$SELECTED_HOSTNAME" --no-root-passwd

    echo "Installation complete! You can now reboot."
  '';

in
{
  mkIso =
    name: modules:
    let
      isoSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [
          {
            nix.registry.nixpkgs.flake = nixpkgs;
            system.nixos.revision = nixpkgs.lib.mkForce nixpkgs.rev;
          }
        ];
      };
    in
    isoSystem.config.system.build.isoImage;

  mkCalamaresIso =
    name: modules:
    let
      isoSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [
          {
            nix.registry.nixpkgs.flake = nixpkgs;
            system.nixos.revision = nixpkgs.lib.mkForce nixpkgs.rev;
            nixpkgs.config.allowBroken = true;
          }

          (import ./calamares-config.nix {
            inherit pkgs lib nixpkgs;
            hostnameSelector = hostnameSelector;
            flakeInstaller = flakeInstaller;
            flakeUrl = "github:flakesonnix/homelab";
            availableHosts = availableHosts;
          })
        ];
      };
    in
    isoSystem.config.system.build.isoImage;
}
