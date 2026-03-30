# Repository State - Current

## Git Status
```
On branch master
Last commit: e04ba71 fix: allow insecure qtwebengine for tor-browser
```

## Recent Commits
- `e04ba71` - fix: allow insecure qtwebengine for tor-browser
- `7bbbb52` - refactor: restructure configuration with profiles and wrappers

## Changes Made (Uncommitted)
- hosts/p50/default.nix: Added btop, htop, hyfetch packages with transgender flag wrapper

## Flake Check Status
```
SUCCESS - All flake outputs pass evaluation
```

## Flake Inputs
- nixpkgs (nixos-unstable)
- home-manager (nix-community/home-manager)
- stylix (nix-community/stylix)
- wrappers (lassulus/wrappers)

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
- vlc, p7zip, tor-browser
- teamspeak3, teamspeak6-client
- btop, htop
- hyfetch (with transgender flag via wrappers)
- noisetorch

### User (home/lucy)
- alacritty, zathura, fzf, bat
- jetbrains-mono (via home.packages)
- easyeffects (with JackHack96 presets)
