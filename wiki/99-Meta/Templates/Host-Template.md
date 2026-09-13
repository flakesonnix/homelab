---
aliases: [Host template]
tags: [template]
type: template
---

# {{title}} (host)

```yaml
aliases: []
tags: [host]
type: host
host: NAME
ip: 10.8.0.X
role: ROLE
hardware: HW
roles: []
deploy: nix run .#deploy-NAME
```

> [!info] Profile
> **Role:** … · **IP:** `…` · **Deploy:** `…`

[[10-Hosts/Hosts-MOC|← Hosts]]

## Features
-

## Data
- `data/hosts/NAME/settings.nix`
- `hosts/NAME/host.nix`

## Modules
-

## Deploy
```bash
nix run .#deploy-NAME
```
