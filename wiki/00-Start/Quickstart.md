---
aliases: [Quickstart]
tags: [start, guide]
type: guide
---

# Quickstart

[[Home|← Home]] · [[00-Start/Welcome|Welcome]] · [[00-Start/Just-Cheatsheet|Cheatsheet]]

## 1. Rebuild p53 locally (default)

```bash
nix run .#rebuild
# = nh os switch, same as: just rebuild
```

Or explicitly:

```bash
sudo nixos-rebuild switch --flake .#p53
```

## 2. Deploy

```bash
nix run .#deploy-p53    # localhost, sshUser root
nix run .#deploy-mireo   # 10.8.0.1, sshUser root
just deploy-all          # p53 and mireo in sequence
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
| [[10-Hosts/p53|p53]] | ThinkPad P53 i7-9750H, Niri, gaming | dynamic (DHCP) / `deploy-p53` |
| [[10-Hosts/mireo|mireo]] | Router/server + 7 VMs | 10.8.0.1 / `deploy-mireo` |

Network map: [[10-Hosts/Network|Network]].

## 5. Data model in 30 seconds

`data/roles/` → `data/bundles/` + `data/presets/` → `data/hosts/<host>/` + `data/home/lucy/` → framework `lib/framework` (`applyHost`/`applyHome`) resolves it.

In depth: [[30-Data-Model/Data-Model|Data model]].
