---
aliases: [NixOS modules, NixOS modules table]
tags: [module, nixos, reference]
type: module
namespace: lucy.*
---

# NixOS modules

[[20-Modules/Modules-MOC|← Modules]] · Source `docs/modules.md`, `modules/nixos/*.nix`.

## Core / base

| Module | Namespace | Purpose |
|-------|-----------|-------|
| `base` | `lucy.base.*` | SSH (key-only, no passwords), sudo, libvirtd (non-server), FW 22/24800/5555-5585, initrd SSH :2222, `trusted-users` |
| `packages` | `lucy.*` | `basePackages`/`hostPackages` + one toggle per `data/packages/system.nix` entry |
| `sops` | `lucy.secrets.*` | sops-nix wrapper, asserts `sopsFile!=null`, `ageKeyPath=/etc/sops/age/keys.txt` |
| `hm-base` | — | HM `useGlobalPkgs`/`useUserPackages`, passes `frameworkLib` via specialArgs |
| `fonts` | `lucy.fonts.*` | e.g. `lucy.fonts.inter=true` |
| `serial-getty` | `lucy.serialGetty.disabled` | e.g. x270 disables ttyS0-3 |
| `topology` | `lucy.topology.*` | → nix-topology `topology.self` |
| `cups` | — | Client side (mireo hosts the cups VM, `profiles/base.nix !isServer` guard) |

## Desktop / gaming / media

| Module | Namespace | Purpose |
|-------|-----------|-------|
| `niri` | `niri.users` | `programs.niri`, xwayland-satellite, portal-gnome restart policy, gvfs/udisks2, `NIXOS_OZONE_WL=1`, greetd+tuigreet |
| `waybar` | `lucy.waybar.*` | `installFonts`, `nerdFonts=[hack symbols-only]` |
| `gnome` / `gnome-extensions` | `lucy.gnome.enable` | Shell + extensions manager, gvfs+Avahi `nssmdns4` for NFS autodiscovery |
| `gaming` | `lucy.gaming.*` | Aggregate → [[20-Modules/Gaming-Stack|Gaming stack]] |
| `latex` | `lucy.latex.*` | texliveSmall, latexmk, biber, texlab, zathura |
| `comfyui` | `lucy.comfyui.*` | Stable Diffusion web UI `:8188`, `gpuSupport none/cuda/rocm` |
| `audio-stream` | `hq.audio.streamTo` | PipeWire tunnel sink → `${streamTo}:4713` |
| `asterisk` | `services.asteriskLocal.*` | SIP PBX via PJSIP, phones/ext 100 hello-world, `*1/*2/*3/#72/#74/*0`, sops templates |
| `deskflow` | `hq.deskflow.*` | Keyboard/mouse sharing server/client, `settings.ini`+`server.conf`, user service lucy |
| `waydroid` | `lucy.waydroid.*` | `enable`, `gapps=true`, oneshot `waydroid init -s GAPPS` |

## Hardware / infra

| Module | Namespace | Purpose |
|-------|-----------|-------|
| `nvidia` | `lucy.nvidia.*` | 32-bit graphics, production driver, `PreserveVideoMemory`, lazy `nvidia-loader` after graphical.target (unused — x270 is Intel) |
| `nvidia-resume` | — | ACPI quirks for suspend/resume |
| `nixfleet` | `lucy.nixfleet.*` | API :8443 + agent — [[50-NixFleet/Manifest-API|details]] |

```dataview
LIST FROM "wiki/20-Modules" WHERE type = "module"
```
