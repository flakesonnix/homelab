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
| `base` | `lucy.base.*` | SSH (key-only, no passwords), sudo, libvirtd (non-server: p53 lokal + mireo `enable=true` als virt-manager-Target), FW 22/24800/5555-5585, initrd SSH :2222, `trusted-users` |
| `packages` | `lucy.*` | `basePackages`/`hostPackages` + one toggle per `data/packages/system.nix` entry |
| `sops` | `lucy.secrets.*` | sops-nix wrapper, asserts `sopsFile!=null`, `ageKeyPath=/etc/sops/age/keys.txt` |
| `hm-base` | — | HM `useGlobalPkgs`/`useUserPackages`, passes `frameworkLib` via specialArgs |
| `lucy-ca` | — | Shared public CA in system trust and Firefox certificate policy; package export `nix build .#lucy-ca`; private key stays on mireo |
| `fonts` | `lucy.fonts.*` | e.g. `lucy.fonts.inter=true` |
| `serial-getty` | `lucy.serialGetty.disabled` | e.g. p53 disables ttyS0-3 |
| `topology` | `lucy.topology.*` | → nix-topology `topology.self` |
| `cups` | — | Client side (mireo hosts the cups VM, `profiles/base.nix !isServer` guard) |

## Desktop / gaming / media

| Module | Namespace | Purpose |
|-------|-----------|-------|
| `niri` | `niri.users` | `programs.niri`, xwayland-satellite, portal-gnome restart policy, gvfs/udisks2, `NIXOS_OZONE_WL=1`, greetd+tuigreet |
| `waybar` | `lucy.waybar.*` | `installFonts`, `nerdFonts=[hack symbols-only]` |
| `gnome` / `gnome-extensions` | `lucy.gnome.enable` | Shell + extensions manager, gvfs+Avahi `nssmdns4` for NFS autodiscovery |
| `dwl-scroll` | `lucy.dwlScroll.*` | Opt-in dwl 0.9 scrolling session, typed settings, dwlb/tray, built-in launcher and optional Discord presence; enabled on p53, details in `docs/dwl-scroll.md` |
| `ewm` | `lucy.ewm.enable` | Emacs Wayland session from the pinned input, session-scoped idle/suspend/manual locking; enabled on p53 |
| `plasma` | `lucy.plasma.*` | Plasma 6 with greetd or SDDM; selecting SDDM disables GDM/greetd; disabled on p53 |
| `sunshine` | `lucy.sunshine.*` | Moonlight host, firewall/KMS capability/autostart default on, web-UI-managed settings; enabled on p53 |
| `gaming` | `lucy.gaming.*` | Aggregate → [[20-Modules/Gaming-Stack|Gaming stack]] |
| `latex` | `lucy.latex.*` | texliveSmall, latexmk, biber, texlab, zathura |
| `comfyui` | `lucy.comfyui.*` | Stable Diffusion web UI `:8188`, `gpuSupport none/cuda/rocm` |
| `audio-stream` | `hq.audio.streamTo` | PipeWire tunnel sink → `${streamTo}:4713` |
| `asterisk` | `services.asteriskLocal.*` | SIP PBX via PJSIP, phones/ext 100 hello-world, `*1/*2/*3/#72/#74/*0`, sops templates |
| `uptime-kuma-sync` | `services.uptime-kuma-sync.*` | Declarative monitors via API (authoritative), timer-driven (boot + daily, never blocks switch), passwordFile |
| `deskflow` | `hq.deskflow.*` | Keyboard/mouse sharing server/client, `settings.ini`+`server.conf`, user service lucy |
| `waydroid` | `lucy.waydroid.*` | `waydroid-nftables` package, `gapps=true`, oneshot `waydroid init -s GAPPS`; no legacy `ip_tables` requirement |

## Hardware / infra

| Module | Namespace | Purpose |
|-------|-----------|-------|
| `nvidia` | `lucy.nvidia.*` | 32-bit graphics, proprietary production or `legacy580` driver, initrd modules + `nvidia-loader`, PRIME bus IDs/offload; p53 uses legacy 580 for Quadro M1000M |
| `nvidia-resume` | — | ACPI quirks for suspend/resume |
| `nixfleet` | `lucy.nixfleet.*` | API :8443 + agent — [[50-NixFleet/Manifest-API|details]] |

```dataview
LIST FROM "wiki/20-Modules" WHERE type = "module"
```
