#!/usr/bin/env bash
set -euo pipefail

# Scaffolds a new NixOS host or mireo microVM.
# Usage:
#   ./scripts/new-host.sh host <name>       # hosts/<name>/
#   ./scripts/new-host.sh vm <name>         # hosts/mireo/<name>-microvm.nix + host import

usage() {
  echo "Usage: $0 host <name> | vm <name>"
  echo "  host <name>  -> hosts/<name>/ (regular NixOS host, x270-style)"
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

# Find next free 10.8.0.x for VMs (10.8.0.2-10.8.0.254, skip .1 host)
next_vm_ip() {
  local used
  used=$(grep -h 'ip = "10\.8\.0\.' hosts/mireo/*-microvm.nix 2>/dev/null | grep -oE '10\.8\.0\.[0-9]+' | cut -d. -f4 | sort -n || true)
  local ip=9
  for u in $used; do
    if [[ "$u" -eq "$ip" ]]; then ip=$((ip+1)); else break; fi
  done
  if (( ip > 254 )); then echo "error: no free VM IP" >&2; exit 1; fi
  echo "10.8.0.$ip"
}

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
  ] ++ (if builtins.pathExists ./generated.nix then [ ./generated.nix ] else []);
}
EOF
    cat > "$dir/host.nix" <<EOF
{config, lib, ...}: {
  networking.hostName = "$name";
  # TODO: set host-specific options here or via purr/data
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
    echo "Next:"
    echo "  1. Edit $dir/host.nix and $dir/hardware-configuration.nix"
    echo "  2. Add to flake.nix: "
    echo "       $name-config = mkHost { specialArgs = x270SpecialArgs; modules = [ ./hosts/$name ]; };"
    echo "       nixosConfigurations.$name = $name-config;"
    echo "  3. nix run ./purr -- check purr/examples/hosts/x270.purr  # or meow.purr"
    echo "  4. just check-light"
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
      # insert before the closing ];
      awk -v f="./$name-microvm.nix" '
        /^\};/ && !done { print "    " f; done=1 }
        { print }
      ' hosts/mireo/default.nix > /tmp/mireo-default.nix.tmp && mv /tmp/mireo-default.nix.tmp hosts/mireo/default.nix
      echo "Added import ./$name-microvm.nix to hosts/mireo/default.nix"
    fi
    echo "Created $file with IP $ip (vm-$name, br0)"
    echo "Next:"
    echo "  1. Edit $file (mem/vcpu/ports/volumes/config)"
    echo "  2. just check-light && nix eval .#nixosConfigurations.mireo.config.microvm.vms.$name.config.networking.hostName --raw"
    echo "  3. Deploy: just deploy-mireo (VM autostart via microvm.host)"
    ;;
  *)
    usage
    ;;
esac
