#!/usr/bin/env bash
set -euo pipefail

# Scaffolds a new NixOS host.
# Usage:
#   ./scripts/new-host.sh host <name>       # hosts/<name>/

usage() {
  echo "Usage: $0 host <name>"
  echo "  host <name>  -> hosts/<name>/ (regular NixOS host, x270-style)"
  exit 1
}

if [[ $# -ne 2 ]]; then usage; fi
kind="$1"
name="$2"

# Validate name: alphanumeric + - _
if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "error: invalid name '$name' (alphanumeric + - _ only)" >&2
  exit 1
fi

case "$kind" in
  host)
    dir="hosts/$name"
    if [[ -e "$dir" ]]; then echo "error: $dir already exists" >&2; exit 1; fi
    mkdir -p "$dir"
    cat > "$dir/default.nix" <<EOF
{nixos-hardware, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
  ];
}
EOF
    cat > "$dir/host.nix" <<EOF
{config, lib, ...}: {
  networking.hostName = "$name";
  # TODO: set host-specific options here or via data/
  # Example:
  # lucy.base.isServer = lib.mkDefault false;
}
EOF
    cat > "$dir/hardware-configuration.nix" <<EOF
# Generated with: nixos-generate-config --show-hardware-config > hosts/$name/hardware-configuration.nix
# TODO: replace with real hardware config (or `nixos-generate-config` on the host)
{config, lib, pkgs, modulesPath, ...}: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [];
  boot.kernelModules = [];
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
  swapDevices = [];
  networking.useDHCP = lib.mkDefault true;
}
EOF
    mkdir -p "data/hosts/$name"
    cat > "data/hosts/$name/settings.nix" <<EOF
# Host-specific settings for $name (data-model)
{...}: {
  # Example: services.printing.enable = true;
}
EOF
    echo "Created $dir/ (default.nix, host.nix, hardware-configuration.nix) + data/hosts/$name/"
    # auto-add to flake.nix if not already present
    if ! grep -q "nixosConfigurations.$name" flake.nix; then
      # Insert <name>-config before live-config (keep live last)
      awk -v n="$name" '
        $0 ~ /^    live-config = mkHost/ && !done {
          print "    " n "-config = mkHost {";
          print "      specialArgs = x270SpecialArgs;";
          print "      modules = [ ./hosts/" n " ];";
          print "    };";
          done=1
        }
        { print }
      ' flake.nix > /tmp/flake.nix.tmp && mv /tmp/flake.nix.tmp flake.nix
      # Insert nixosConfigurations.<name> before live
      awk -v n="$name" '
        $0 ~ /live = live-config;/ && !done2 {
          print "            " n " = " n "-config;";
          done2=1
        }
        { print }
      ' flake.nix > /tmp/flake.nix.tmp && mv /tmp/flake.nix.tmp flake.nix
      echo "Added $name-config + nixosConfigurations.$name to flake.nix (add deploy.nodes.$name manually if needed)"
    else
      echo "flake.nix already contains $name (skipped auto-add)"
    fi
    echo "Next:"
    echo "  1. Edit $dir/host.nix and $dir/hardware-configuration.nix"
    echo "  2. just check-light && nix eval .#nixosConfigurations.$name.config.system.build.toplevel.outPath --raw"
    ;;
  *)
    usage
    ;;
esac
