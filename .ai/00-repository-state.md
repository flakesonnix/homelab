# Repository State - Current

## Git Status
```
On branch master
Last commit: 676498d feat: add nix-index-database with comma, fix niri and zsh warnings
```

## Recent Commits
- `676498d` - feat: add nix-index-database with comma, fix niri and zsh warnings
- `67dd379` - docs: sync documentation with latest commit
- `425d201` - feat: migrate to flake-parts, add nixos-hardware and sops-nix
- `d75ffe0` - docs: update documentation with wpaperd and recent changes

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
- deploy-rs (serokell/deploy-rs)
- nix-index-database (nix-community/nix-index-database)

## Directory Structure
```
./flake.nix
./deploy.sh
./.gitignore
./.ai/
./docs/
./flake.lock
./home/
  ./lucy/
    ./default.nix
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/
      ./easyeffects/
      ./htop.nix
      ./btop.nix
      ./packages.nix
./hosts/
  ./p50/
    ./default.nix
    ./hardware-configuration.nix
    ./secrets.yaml
  ./desktop/  (DeskFlow client)
    ./default.nix
    ./hardware-configuration.nix
  ./omen/  (DeskFlow client)
    ./default.nix
    ./hardware-configuration.nix
  ./vm/
    ./default.nix  # microvm config (commented out)
./lib/
  ./default.nix
./modules/
  ./home/
    ./stylix.nix
    ./waybar.nix
  ./nixos/
    ./network.nix  # Static IP module
    ./ssh-keys.nix  # SSH key authorization
    ./niri.nix
    ./latex.nix
./nix-settings.nix
./profiles/
  ./base.nix
  ./desktop.nix
./README.md
```

## Packages Installed
### System (hosts/p50)
- vesktop (Discord client with Vencord)
- vlc, p7zip
- thunderbird
- btop, htop
- hyfetch (with transgender flag via wrappers)
- noisetorch
- deskflow
- gnomeExtensions.dash-to-dock

### MicroVM (hosts/vm)
- Lightweight NixOS VM via microvm.nix (not active)

### User (home/lucy)
- alacritty, zathura, fzf, bat
- jetbrains-mono
- easyeffects (with JackHack96 presets)
- com.teamspeak.TeamSpeak (via flatpak)
- wpaperd
- gnomeExtensions.dash-to-dock

## Network Configuration
Static IP module at `modules/nixos/network.nix`:
- `networking.staticIP.enable` - Enable static IP
- `networking.staticIP.address` - IP address
- `networking.staticIP.prefixLength` - Network prefix (default: 24)
- `networking.staticIP.gateway` - Gateway IP
- `networking.staticIP.interface` - Network interface
- `networking.staticIP.dns` - DNS servers

## Deployment
Using deploy-rs for multi-host deployment:
```bash
nix develop  # Enter dev shell with deploy-rs
deploy .#p50 .#desktop .#omen  # Deploy all hosts
deploy .#p50  # Deploy single host
deploy .#p50 --dry-activate  # Dry run
```

## SSH Configuration
- SSH key authorization via `modules/nixos/ssh-keys.nix`
- Keys added to both `lucy` and `root` users
- PermitRootLogin = "prohibit-password" (SSH key only)
- Firewall: ports 22, 24800 (DeskFlow) open

## DeskFlow
- Multi-mouse/keyboard sharing between machines
- Port 24800/TCP open on all hosts
- All hosts use same configuration (p50 config)
