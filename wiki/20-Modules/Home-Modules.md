---
aliases: [Home modules, HM modules]
tags: [module, nixos]
type: module
namespace: programs.*
---

# Home modules

[[20-Modules/Modules-MOC|← Modules]] · Auto-imported via `modules/home/default.nix`: `niri`, `opencode`, `ssh`, `stylix`, `waybar` (+`dunst` via `home/lucy/default.nix`).

## niri (`programs.niri.enable`)

Generates `~/.config/niri/config.kdl` (KDL renderers + Stylix palette):
- Input: numlock on, tap + natural scroll · Layout: 22px gaps, center-on-overflow, 3px border (base0E active/base03 inactive), drop shadow
- Startup: polkit agent, xwayland-satellite, swaybg wallpaper (if `WALLPAPER` set), waybar or eww
- Rules: Firefox PiP → floating, 16px corner radius everywhere · swaylock-effects + wlogout
- Keys: `Alt+Enter/D/O/W/F/V`, `Alt+[1-9]` (+Ctrl/Shift variants), HJKL+arrows, media keys work when locked
- Packages: blueman, brightnessctl, grim, nm-applet, playerctl, slurp, swaylock-effects, wl-clipboard, wlogout

## waybar (`programs.waybar.enable`)

Top bar, 42px height, 14px top margin, 18px side margins. Stylix gradient + card-style modules.
Left `niri/workspaces+window` · center `mpris` · right `notifications/idle/clock/network/pulse/battery/cpu/memory/tray/power`.
Clicks: mpris play/pause + notify art + fuzzel picker, notifications poll makoctl every 3s, power→wlogout, cpu/mem→btop.

## stylix

`stylix.enable` → dark polarity, most targets on (waybar/GTK/bat/btop/fzf/firefox), alacritty/mako/rofi/zathura off (custom configs). Removes legacy Kvantum symlink.

## ssh / opencode / dunst

- `ssh`: client config, known hosts.
- `opencode`: AI coding tool config (`modules/home/opencode.nix`).
- `dunst`: notification daemon, auto-disabled while `programs.niri.enable` (niri setups use mako).
