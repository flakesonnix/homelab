---
aliases: [Roles, Bundles, Presets, Packages]
tags: [nixos, reference]
type: reference
---

# Roles → bundles + presets + packages

[[30-Data-Model/Data-Model|← Data model]]

## Roles (`data/roles/*.nix`)

Shape: `meta{description,targets[host home],requires,conflicts}` + `host{moduleFlags,packageTags,presets}` + `home{bundles}`.

| Role | Targets | Effect |
|-------|---------|--------|
| `core` | home | Activates `core` bundle |
| `desktop` | host+home | niri/fonts/waybar fonts + `desktop` bundle |
| `dev` | host+home | dev/net/monitoring tags + `dev` bundle |
| `gaming` | host | Applies `gaming-base/-performance/-steam` presets |
| `llm` | host | Adds `llm` package tag |

Hosts: `x270=[desktop dev gaming]`, `mireo=[]`, `home/lucy=[core desktop dev]`.

## Bundles (`data/bundles/*.nix`)

Home Manager slices with `programs.*`, `settings.stylix`, `packageToggles` (from the `home.nix` registry), `services.flatpak`, `home.*`, `xdg.desktopEntries`.

| Bundle | Contains |
|--------|---------|
| `core` | bash, git, nvim, htop/btop, bat, fzf, ssh, opencode, nh; comma, manix, nix-output-monitor |
| `desktop` | alacritty, dunst, eww, firefox, fuzzel, gnomeTheme, niri, rofi, starship, thunderbird, vesktop, zathura; stylix; TeamSpeak flatpak; jetbrains-mono, nautilus |
| `dev` | android-studio |

## Presets (`data/presets/*.nix`)

`{meta, moduleFlags}` — referenced by roles via `host.presets`. See [[20-Modules/Gaming-Stack|Gaming]].

## Package registries

`data/packages/system.nix`: `{description,targets[user/system/font],packages.user,tags}` — e.g. firefox, discord, lmstudio, clion, ollama, swaybg, devBase, pwvucontrol, scrcpy, nload, iotop, iftop. Roles collect packages via `packageTags` intersection.
`data/packages/home.nix`: comma, manix, nix-output-monitor, jetbrains-mono, nautilus, android-studio — via `packageToggles`.
