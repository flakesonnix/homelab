# dotfiles task runner — run `just` to list commands.
# Most recipes wrap `nix run .#<app>` flake apps.

# List available commands
default:
    @just --list

# Rebuild the local host (x270) via nh
rebuild:
    nix run .#rebuild

# Deploy x270 via deploy-rs to localhost
deploy-x270:
    nix run .#deploy-x270

# Alias for deploy-x270 (local thinkpad)
deploy:
    nix run .#deploy-x270

# Deploy mireo to 10.8.0.1 via deploy-rs
deploy-mireo:
    nix run .#deploy-mireo

# Deploy all hosts via deploy-rs
deploy-all:
    nix run .#deploy-x270
    nix run .#deploy-mireo

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

# Generate sops-nix age key pair (host: x270)
sops host="x270":
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

# Interactive command launcher (fzf)
menu:
    nix run .#menu
