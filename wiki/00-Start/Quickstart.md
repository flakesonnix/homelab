---
aliases: [Quickstart]
tags: [start, guide]
type: guide
---

# Quickstart

[[Home|← Home]] · [[00-Start/Welcome|Welcome]] · [[00-Start/Just-Cheatsheet|Cheatsheet]]

## 1. Rebuild x270 locally (default)

```bash
nix run .#rebuild
# = nh os switch, same as: just rebuild
```

Or explicitly:

```bash
sudo nixos-rebuild switch --flake .#x270
```

## 2. Deploy

```bash
nix run .#deploy-x270    # localhost, sshUser root
nix run .#deploy-mireo   # 10.8.0.1, sshUser root
nix run .#deploy-nyagate # db210.org, ssh lucy → sudo root
just deploy-all          # all three in sequence
```

Details: [[40-Guides/Deploy-Rebuild|Deploy & rebuild]].

## 3. Check / format / lint

```bash
nix run .#check-light   # eval surface: formatter, devShell, apps
nix run .#check         # full: + dotfiles-tests build
nix run .#check-full    # builds only
nix fmt                 # alejandra
statix check            # lint (just lint)
```

CI: 6 jobs — see [[60-Reference/Flake-CI-Topology|Flake · CI · topology]].

## 4. Host overview

| Host | What | IP / deploy |
|------|-----|-------------|
| [[10-Hosts/x270|x270]] | ThinkPad X270 i7-7600U, Niri, gaming | dynamic (DHCP) / `deploy-x270` |
| [[10-Hosts/mireo|mireo]] | Router/server + 7 VMs | 10.8.0.1 / `deploy-mireo` |
| [[10-Hosts/nyagate|nyagate]] | Remote QEMU | db210.org / `deploy-nyagate` |
| [[10-Hosts/live-iso|live-iso]] | Installer | `nix build .#packages.x86_64-linux.live-iso` |

Network map: [[10-Hosts/Network|Network]].

## 5. Data model in 30 seconds

`data/roles/` → `data/bundles/` + `data/presets/` → `data/hosts/<host>/` + `data/home/lucy/` → framework `lib/framework` (`applyHost`/`applyHome`) resolves it.

In depth: [[30-Data-Model/Data-Model|Data model]].
