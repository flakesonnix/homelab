# dotfiles task runner — run `just` to list commands.
# Most recipes wrap `nix run .#<app>` flake apps.

# List available commands
default:
    @just --list

# Rebuild the local host (p53) via nh
rebuild:
    nix run .#rebuild

# Deploy p53 via deploy-rs to localhost
deploy-p53:
    nix run .#deploy-p53

# Alias for deploy-p53 (local thinkpad)
deploy:
    nix run .#deploy-p53

# Deploy mireo to 10.8.0.1 via deploy-rs
deploy-mireo:
    nix run .#deploy-mireo

# Deploy nyagate to db210.org via deploy-rs (ssh as lucy, sudo to root)
deploy-nyagate:
    nix run .#deploy-nyagate

# Deploy all hosts via deploy-rs
deploy-all:
    nix run .#deploy-p53
    nix run .#deploy-mireo
    nix run .#deploy-nyagate

# Fast eval-surface checks (formatter, devShell, app paths)
check-light:
    nix run .#check-light

# Full CI check builds
check-full:
    nix run .#check-full

# Run nix flake check
check:
    nix run .#check

# Update flake inputs
update:
    nix run .#update

# Format all nix files (alejandra)
fmt:
    nix fmt

# Lint with statix
lint:
    statix check

# Generate sops-nix age key pair (host: p53)
sops host="p53":
    nix run .#setup-sops {{host}}

# Build network/host topology SVGs → ./result/
topology:
    nix build .#topology

# nixfleet CLI (status, health)
nixfleet:
    nix run .#nixfleet

# NixFleet docs framework
docs-generate:
    nix run .#nixfleet -- docs generate

docs-check:
    nix run .#nixfleet -- docs check

docs-build:
    nix run .#nixfleet -- docs build

docs-serve:
    nix run .#nixfleet -- docs serve

# Build NixOS GNOME netboot payload for PXE (→ ./result/, sync to mireo:/data/pxe)
pxe-boot:
    nix build .#pxe-desktop-boot

# Interactive command launcher (fzf)
menu:
    nix run .#menu

# Scaffold a new NixOS host (./hosts/<name>/)
new-host name:
    ./scripts/new-host.sh host {{name}}

# Scaffold a new microVM on mireo (./hosts/mireo/<name>-microvm.nix, 10.8.0.x)
new-vm name:
    ./scripts/new-host.sh vm {{name}}
