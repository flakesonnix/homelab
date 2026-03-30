# Repository State - Current

## Git Status
```
working tree dirty (uncommitted changes)
```

## Changes Made (Uncommitted)
- flake.nix: Added profiles/desktop.nix to modules, simplified structure
- hosts/p50/default.nix: Refactored to use profiles
- profiles/base.nix: Added GPG agent configuration
- profiles/desktop.nix: Added as desktop profile
- modules/nixos/default.nix: Removed nix-settings import (now in flake.nix)
- modules/home/default.nix: Fixed module signature for NixOS
- modules/home/stylix.nix: Fixed mkIf condition, custom color scheme
- home/lucy/default.nix: Added easyeffects module import, enabled stubs
- home/lucy/shell.nix: Enhanced zsh configuration
- home/lucy/git.nix: Updated to new home-manager git settings format
- home/lucy/editor.nix: Enhanced neovim configuration
- home/lucy/programs/easyeffects/: New module for easyeffects with presets
- Added packages: teamspeak3, teamspeak6-client, easyeffects

## Flake Check Status
```
SUCCESS - All flake outputs pass evaluation
```

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
