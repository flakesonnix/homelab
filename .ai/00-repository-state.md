# Repository State - Current

## Git Status
```
On branch master
Last commit: 1c95ff8 fix(docs): fix metadata path and simplify build
```

## Recent Commits
- `1c95ff8` - fix(docs): fix metadata path and simplify build
- `ac36638` - feat: add nix-flatpak for TeamSpeak and cleanup packages
- `92d1adb` - docs: update documentation with latest changes
- `7bbbb52` - refactor: restructure configuration with profiles and wrappers

## Changes Made (Uncommitted)
- hosts/p50/default.nix: Added wpaperd to spawn-at-startup, added Mod+W for close-window
- home/lucy/default.nix: Added wpaperd package and services.wpaperd configuration

## Flake Check Status
```
SUCCESS - All flake outputs pass evaluation
```

## Flake Inputs
- nixpkgs (nixos-unstable)
- home-manager (nix-community/home-manager)
- stylix (nix-community/stylix)
- wrappers (lassulus/wrappers)
- nix-flatpak (gmodena/nix-flatpak)

## Directory Structure
```
./flake.nix
./.gitignore
./.ai/
./docs/
./flake.lock
./home/
  ./lucy/
    ./default.nix
    ./editor.nix
    ./git.nix
    ./packages.nix
    ./shell.nix
    ./programs/
      ./easyeffects/
      ./alacritty/
      ./bat/
      ./fzf/
      ./niri/
      ./zathura/
./hosts/
  ./p50/
    ./default.nix
    ./hardware-configuration.nix
./lib/
  ./default.nix
./modules/
  ./home/
    ./default.nix
    ./latex.nix
    ./ssh.nix
    ./stylix.nix
    ./waybar.nix
  ./nixos/
    ./default.nix
    ./latex.nix
    ./niri.nix
./nix-settings.nix
./profiles/
  ./base.nix
  ./desktop.nix
./README.md
```

## Packages Installed
### System (hosts/p50)
- niri (via programs.niri.enable + wrappers)
- vesktop (Discord client with Vencord)
- vlc, p7zip
- thunderbird
- btop, htop
- hyfetch (with transgender flag via wrappers)
- noisetorch

### User (home/lucy)
- alacritty, zathura, fzf, bat
- jetbrains-mono (via home.packages)
- easyeffects (with JackHack96 presets)
- com.teamspeak.TeamSpeak (via flatpak)
- wpaperd (with s-l1600.jpg wallpaper)

## Niri Keybindings
- Mod+Return: spawn alacritty
- Mod+D: spawn fuzzel
- Mod+Q/W: close window
- Mod+[HJKL/Arrows]: focus navigation
- Mod+Ctrl+[HJKL/Arrows]: move window
- Mod+[1-9]: workspace focus
- Mod+R: switch column width
- Mod+F: maximize column
- Mod+Shift+F: fullscreen
