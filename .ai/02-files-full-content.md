# File Documentation - Key Files Summary

This file documents the structure of key configuration files. For full content, use `cat` or `nix eval` on the actual files.

## Key Files

### ./flake.nix
- Entry point for NixOS flake
- Inputs: nixpkgs (nixos-unstable), home-manager, stylix, wrappers, nix-flatpak
- Outputs: nixosConfigurations.p50, homeConfigurations."lucy@p50", devShells, formatter
- specialArgs: passes `wrappers` to NixOS modules

### ./hosts/p50/default.nix
- Main host configuration for ThinkPad P50
- Wraps niri with Lassulus wrappers for declarative config
- Wraps hyfetch with transgender flag
- Installs packages: alacritty, zathura, fzf, bat, btop, htop, vesktop, vlc, p7zip, thunderbird
- Enables: programs.niri, programs.noisetorch, services.openssh
- Spawns at startup: waybar, wpaperd

### ./home/lucy/default.nix
- Home-manager configuration for user lucy
- Enables modules: lucy.shell, lucy.git, lucy.editor, lucy.easyeffects
- Configures: programs.waybar, home.packages, stylix, gtk, services.wpaperd, services.flatpak
- Packages: jetbrains-mono, wpaperd

### ./profiles/base.nix
- Base profile with common NixOS settings
- Environment variables (EDITOR=vim)
- Locale, allowUnfree, firefox, printing, rtkit, gnupg agent

### ./profiles/desktop.nix
- Desktop profile with display manager and PipeWire
- GDM, GNOME, X server, PipeWire (alsa, pulse)

### ./modules/home/stylix.nix
- Custom module for stylix theming
- Custom base16 color scheme (dark theme)

### ./modules/home/waybar.nix
- Waybar configuration module (currently not imported)

### ./home/lucy/programs/easyeffects/default.nix
- Fetches presets from JackHack96/EasyEffects-Presets
- Installs easyeffects package
- Symlinks presets to ~/.config/easyeffects/

### ./home/lucy/shell.nix, git.nix, editor.nix, packages.nix
- Home-manager module stubs for zsh, git, neovim, additional packages
- All enabled via lucy.<module>.enable options

## Package Locations

### System packages (hosts/p50/default.nix → users.users.lucy.packages)
- alacritty, zathura, fzf, bat
- vesktop, vlc, p7zip
- thunderbird
- btop, htop

### User packages (home/lucy/default.nix → home.packages)
- jetbrains-mono, wpaperd

### Environment packages (hosts/p50/default.nix → environment.systemPackages)
- niri (wrapped), hyfetch (wrapped)

### Flatpak packages (home/lucy/default.nix → services.flatpak)
- com.teamspeak.TeamSpeak
