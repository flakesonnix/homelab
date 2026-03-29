# Design Decisions - Complete Record

## Decision 1: Nixpkgs Version - 24.11 Instead of nixos-unstable

### Context
Initial setup intended to use nixos-unstable as per requirements.

### Decision
Use nixpkgs 24.11 (stable) instead of nixos-unstable.

### Reason
The nixos-unstable channel (specifically revision 46db2e09e1d3f113a13c0d7b81e2f221c63b8ce9 from 2026-03-24) has a bug in `nixos/modules/config/console.nix`:
```
error: attribute 'mkRenamedOptionModule' missing
```

This is a breaking change in nixpkgs that was later fixed. Using 24.11 stable provides a working configuration.

### Alternatives Considered
1. Continue using nixos-unstable and wait for fix - REJECTED: Blocks all progress
2. Pin to a newer nixos-unstable revision - REJECTED: Could not find working revision
3. Use NixOS 24.11 stable - ACCEPTED: Works reliably

---

## Decision 2: niri-flake Integration - Removed

### Context
User requested integration of niri-flake for Wayland compositor management.

### Decision
Removed niri-flake after initial integration attempt.

### Reason
When niri-flake was added to the flake inputs and the nixosModules.niri was imported, it triggered the same mkRenamedOptionModule bug:
```
error: attribute 'mkRenamedOptionModule' missing
at /nix/store/fvb3fhm8c193i6692v5223bxpa5w2nv7-source/nixos/modules/config/console.nix
```

This happens because niri-flake imports nixpkgs modules that reference the broken console.nix.

### Current Approach
Niri is configured using the nixpkgs package directly (pkgs.niri) without niri-flake:
- System-level: modules/nixos/niri.nix installs pkgs.niri
- User-level: home/lucy/default.nix installs pkgs.niri and writes KDL config manually

### Alternatives Considered
1. Try niri-flake unstable version - REJECTED: Same module compatibility issue
2. Use pkgs.niri directly - ACCEPTED: Works, minimal configuration needed

---

## Decision 3: nixos-hardware Integration - Removed

### Context
User requested integration of nixos-hardware for ThinkPad P50 (hybrid GPU, specific hardware).

### Decision
Removed nixos-hardware after initial integration attempt.

### Reason
Same mkRenamedOptionModule bug triggered when nixos-hardware.nixosModules.lenovo-thinkpad-p50 was imported.

### Hardware Details (Known from nixos-hardware)
```
lenovo-thinkpad-p50 imports:
- common/gpu/nvidia/prime.nix
- common/gpu/nvidia/maxwell
- common/cpu/intel
- ../. (lenovo-thinkpad base)

NVIDIA PRIME config (from prime.nix):
- hardware.nvidia.prime.offload.enable = true
- hardware.nvidia.prime.intelBusId = "PCI:0:2:0"
- hardware.nvidia.prime.nvidiaBusId = "PCI:1:0:0"

Hardware details from hosts/p50/hardware-configuration.nix:
- boot.kernelModules = [ "kvm-intel" ]
- Root: LUKS encrypted ext4
- Boot: EFI vfat
- Swap: LUKS encrypted
- CPU: Intel with microcode
```

### Alternatives Considered
1. Wait for nixpkgs fix, then re-add - PLANNED: When nixos-unstable works again
2. Manually configure hardware - ACCEPTED: Current approach in hardware-configuration.nix

---

## Decision 4: Network Configuration - Basic NetworkManager

### Context
p50 has two network interfaces:
- enp0s31f6: Wired ethernet, 192.168.178.0/24
- wlp4s0: WiFi

### Decision
Use NetworkManager for both interfaces with no custom bridge/NAT yet.

### Current Configuration
```nix
networking.networkmanager.enable = true;
```

### Future Plans (NOT YET IMPLEMENTED)
- microvm.nix integration for running VMs
- Bridge interface for microvm network isolation
- NAT for microvm outbound traffic

---

## Decision 5: GNOME Desktop Instead of Niri (Initial Setup)

### Context
Both GNOME and niri are configured but GNOME is the default.

### Decision
hosts/p50/default.nix enables GNOME:
```nix
services.xserver.enable = true;
services.xserver.displayManager.gdm.enable = true;
services.xserver.desktopManager.gnome.enable = true;
```

### User-Level Niri
home/lucy/default.nix installs niri and provides config, but GNOME is still the primary DE.

### Reason
GNOME provides a complete desktop environment out of the box. Niri is a more minimal Wayland compositor that requires more manual configuration.

---

## Decision 6: lib/default.nix - Minimal Helper Functions

### Context
Framework goal was to create mkHost, mkUser helpers.

### Decision
Only mkUser is implemented. mkHost is not needed yet because:
- nixosConfigurations are defined directly in flake.nix
- The pattern is simple enough to not need abstraction

### Current lib/default.nix
```nix
{
  mkUser =
    { username
    , description ? ""
    , modules ? [ ]
    }:
    {
      inherit username modules description;
    };
}
```

### Future Plans
- Add more helpers as the configuration grows
- Could add mkHost when more hosts are added

---

## Decision 7: Host p50 - Username in Both flake.nix and hosts/p50

### Context
User lucy is defined in both places.

### Decision
User is defined in flake.nix in the nixosConfigurations.p50 modules list:
```nix
users.users.lucy.isNormalUser = true;
users.users.lucy.description = "Lucy";
users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
```

And also in hosts/p50/default.nix (from original nixos-generate-config).

### Reason
The flake.nix version is for when building via flake. The hosts/p50 version would be for when deploying directly. Currently both are kept for compatibility.

---

## Decision 8: Profiles - Not Yet Used

### Context
profiles/base.nix and profiles/desktop.nix were created.

### Decision
Profiles are NOT currently imported or used in the active configuration.

### Reason
The hosts/p50/default.nix has all the configuration directly. Profiles could be imported to provide composable layers:
- profiles/base.nix: Common system config
- profiles/desktop.nix: Desktop-specific config

### Future Plans
- Import profiles into hosts/p50/default.nix for better modularity
- Use profiles as imports: `imports = [ ../profiles/desktop.nix ];`

---

## Decision 9: Home-Manager Modules - Stubs

### Context
modules/home/default.nix and individual module files (shell.nix, git.nix, etc.) have enable options.

### Decision
Currently all enable options are false by default:
```nix
config = lib.mkIf (lib.mkDefault false) { };
```

### Reason
This allows users to opt-in to specific configurations. Currently:
- lucy.shell.enable = false (not used)
- lucy.git.enable = false (not used)  
- lucy.editor.enable = false (not used)
- lucy.packages.enable = false (not used)

The actual configurations in home/lucy/default.nix are applied unconditionally.

### Future Plans
- Flip enable options to true as configurations are finalized
- Or remove the enable options and always apply configurations

---

## Decision 10: Constraint - No Garbage Collection

### Context
Requirements stated: no automatic garbage collection.

### Implementation
This constraint is followed by:
- NOT setting any nix.gc.* options
- NOT adding any nix-collect-garbage commands
- nix.settings.auto-optimise-store = true is SET (this is different - it hardlinks, doesn't delete)

---

## Decision 11: Constraint - No nixpkgs.lib Shadowing

### Context
Early in development, there was an error with mkRenamedOptionModule.

### Root Cause
The flake.nix had:
```nix
specialArgs = { lib = myLib; };
```

This shadowed nixpkgs.lib with the custom lib, breaking NixOS module system.

### Decision
Remove specialArgs entirely:
```nix
nixosConfigurations.p50 = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [ ... ];
};
```

### Reason
NixOS modules need access to nixpkgs.lib. Our custom lib (lib/default.nix) is passed via the flake output `lib = myLib;` which is separate from the NixOS module system's lib.

---

## Future Design Decisions Needed

1. **MicroVM Integration**: When nixpkgs is fixed, add microvm.nix for running VMs
2. **nixos-hardware Integration**: When nixpkgs is fixed, add proper GPU/PRIME config
3. **GPG/USB Key Integration**: User requested but not yet implemented
4. **SOPS Integration**: User mentioned but not yet implemented
5. **flake-parts Migration**: Could improve flake organization
6. **Profile Usage**: Currently profiles are defined but not used
