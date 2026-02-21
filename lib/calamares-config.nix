{ pkgs, lib, hostnameSelector, flakeInstaller, flakeUrl, availableHosts, nixpkgs }:

let
  calamaresModule = import (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix") { inherit pkgs; };
in
{
  imports = [ calamaresModule ];

  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
  };

  boot.supportedFilesystems = [ "btrfs" "ext4" "vfat" "ntfs" "xfs" ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    hostnameSelector
    flakeInstaller
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "24.11";

  environment.etc = {
    "calamares/modules/shellprocess-flake.conf".text = ''
      # SPDX-FileCopyrightText: no
      # SPDX-License-Identifier: CC0-1.0
      #
      # Shell process job for installing NixOS from flake after partitioning
      dontChroot: false
      timeout: 600
      script:
        - |
          # Clone the flake and install NixOS
          FLAKE_URL="${flakeUrl}"
          SELECTED_HOSTNAME=$(cat /tmp/selected-hostname 2>/dev/null || echo "nixos")

          echo "==========================================="
          echo "Installing NixOS from flake: $FLAKE_URL#$SELECTED_HOSTNAME"
          echo "==========================================="

          cd /tmp
          rm -rf homelab
          git clone --depth 1 "$FLAKE_URL" homelab

          if [ -d /tmp/homelab ]; then
            cd /tmp/homelab
            nixos-install --flake .#"$SELECTED_HOSTNAME" --no-root-passwd
            echo "Installation complete!"
          else
            echo "Error: Could not clone flake"
            exit 1
          fi
    '';
  };
}
