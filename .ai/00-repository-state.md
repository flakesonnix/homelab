# Repository State - Current

## Git Status
```
On branch master
Last commit: 425d201 feat: migrate to flake-parts, add nixos-hardware and sops-nix
```

## Recent Commits
- `425d201` - feat: migrate to flake-parts, add nixos-hardware and sops-nix
- `d75ffe0` - docs: update documentation with wpaperd and recent changes
- `1c95ff8` - fix(docs): fix metadata path and simplify build

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
- nixos-hardware (NixOS/nixos-hardware)
- sops-nix (Mic92/sops-nix)
- flake-parts (hercules-ci/flake-parts)

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
    ./secrets.yaml
  ./vm/
    ./default.nix  # microvm config (commented out)
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

### MicroVM (hosts/vm)
- Lightweight NixOS VM via microvm.nix (not active)
- Can be enabled by uncommenting in flake.nix

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
