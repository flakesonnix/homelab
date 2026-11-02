#!/usr/bin/env bash
set -euo pipefail

# Scaffolds a new NixOS host or mireo microVM.
# Usage:
#   ./scripts/new-host.sh host <name>       # hosts/<name>/
#   ./scripts/new-host.sh vm <name>         # hosts/mireo/<name>-microvm.nix + host import

usage() {
  echo "Usage: $0 host <name> | vm <name>"
  echo "  host <name>  -> hosts/<name>/ (regular NixOS host, p53-style)"
  echo "  vm <name>    -> hosts/mireo/<name>-microvm.nix (microvm on mireo, 10.8.0.x)"
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

# Find a free service address, including central reservations and disabled specs.
next_vm_ip() {
  local used
  used=$(grep -hoE '10\.8\.0\.[0-9]+' hosts/mireo/vm-ips.nix hosts/mireo/*-microvm.nix | cut -d. -f4 | sort -nu)
  local ip
  for ((ip=2; ip<=254; ip++)); do
    # Never allocate from dnsmasq's dynamic client range.
    if (( ip >= 100 && ip <= 199 )); then continue; fi
    if ! grep -qx "$ip" <<< "$used"; then
      echo "10.8.0.$ip"
      return
    fi
  done
  echo "error: no free VM IP" >&2
  return 1
}

case "$kind" in
  host)
    dir="hosts/$name"
    if [[ -e "$dir" || -e "data/hosts/$name" ]]; then
      echo "error: host directory or data for $name already exists" >&2
      exit 1
    fi
    for marker in scaffold:host-definitions scaffold:host-registrations; do
      if [[ $(grep -c "$marker" flake.nix) != 1 ]]; then
        echo "error: expected one $marker marker in flake.nix" >&2
        exit 1
      fi
    done
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
# TODO: replace with real hardware config (or nixos-generate-config on the host)
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
    # Explicit markers survive nixfmt; never infer Nix structure from indentation.
    temp=$(mktemp flake.nix.XXXXXX)
    trap 'rm -f -- "$temp"' EXIT
    awk -v n="$name" '
      /# scaffold:host-definitions/ {
        print "    " n "-config = mkHost {";
        print "      specialArgs = p53SpecialArgs;";
        print "      modules = [ ./hosts/" n " ];";
        print "    };";
      }
      /# scaffold:host-registrations/ { print "            " n " = " n "-config;" }
      { print }
    ' flake.nix > "$temp"
    mv -- "$temp" flake.nix
    echo "Added $name-config + nixosConfigurations.$name to flake.nix (add deploy.nodes.$name manually if needed)"
    if command -v nixfmt >/dev/null; then
      nixfmt flake.nix "$dir/default.nix" "$dir/host.nix" "data/hosts/$name/settings.nix"
    fi
    echo "Next:"
    echo "  1. Edit $dir/host.nix and $dir/hardware-configuration.nix"
    echo "  2. just check-light && nix eval .#nixosConfigurations.$name.config.system.build.toplevel.outPath --raw"
    ;;
  vm)
    if [[ ! -d "hosts/mireo" ]]; then echo "error: hosts/mireo not found" >&2; exit 1; fi
    file="hosts/mireo/$name-microvm.nix"
    if [[ -e "$file" ]]; then echo "error: $file already exists" >&2; exit 1; fi
    ip=$(next_vm_ip)
    # pick next vm-* bridge name is auto via interfaceId = vm-<name>
    cat > "$file" <<EOF
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "$name";
      ip = "$ip";
      mem = 512;
      vcpu = 1;
      tcpPorts = [22];
      volumes = [
        # Example:
        # { image = "$name-data.img"; mountPoint = "/var/lib/$name"; size = 1024; user = "$name"; group = "$name"; }
      ];
      config = {
        # TODO: VM NixOS config here
        # services.openssh.enable = true;
      };
    })
  ];
}
EOF
    # auto-add import to hosts/mireo/default.nix if not already present
    if ! grep -q "$name-microvm.nix" hosts/mireo/default.nix; then
      # Insert before the imports list closes, not before the module's closing }.
      temp=$(mktemp hosts/mireo/default.nix.XXXXXX)
      trap 'rm -f -- "$temp"' EXIT
      awk -v f="./$name-microvm.nix" '
        /^[[:space:]]*imports = \[/ { in_imports=1 }
        in_imports && /^[[:space:]]*\];/ && !done { print "    " f; done=1 }
        { print }
        END { if (!done) exit 1 }
      ' hosts/mireo/default.nix > "$temp"
      mv -- "$temp" hosts/mireo/default.nix
      echo "Added import ./$name-microvm.nix to hosts/mireo/default.nix"
    fi
    if command -v nixfmt >/dev/null; then
      nixfmt "$file" hosts/mireo/default.nix
    fi
    echo "Created $file with IP $ip (vm-$name, br0)"
    echo "Next:"
    echo "  1. Edit $file (mem/vcpu/ports/volumes/config)"
    echo "  2. just check-light && nix eval .#nixosConfigurations.mireo.config.microvm.vms.$name.config.networking.hostName --raw"
    echo "  3. Deploy: just deploy-mireo (VM autostart via microvm.host)"
    echo "  4. Register the IP in hosts/mireo/vm-ips.nix so DNS + proxy pick it up"
    ;;
  *)
    usage
    ;;
esac
