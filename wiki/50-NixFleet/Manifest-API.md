---
aliases: [Manifest, API, Agent, ui.json]
tags: [nixfleet, reference, guide]
type: reference
---

# Manifest & API (M1)

[[50-NixFleet/NixFleet-MOC|← NixFleet]]

## Pipeline

`flake.nix` → `nixfleetArtifacts=import ./nixfleet/manifest.nix {lib,pkgs,configurations=without live,deployNodes}` → `packages.nixfleet-manifest/ui` (`writeText`) → committed to `nixfleet/artifacts/` (CI on master only) → `nixfleet-api --manifest … --ui … [--web …]` serves them.

Fixes in 7a05039: `hasVms` via `attrNames vmCatalog` (was always false), `hostRoles` via `hasAttr "roles.nix"` (was invalid `? roles.nix`) → x270 now shows `[desktop dev gaming]`, `/vms` nav appears. mireo `roles:[]` is intentional (server, configured directly in settings.nix).

## manifest.json (v1)

- `hosts.<name>`: `hostname, roles, bundles, presets, moduleFlags, packageTags, packages{tag->[pkg]}`
- `vms.<vm>`: `host=mireo, ip, mem, vcpu, autostart, tcpPorts, udpPorts, volumes[]` (from `microvm.vms`, `20-lan` address, `microvm.{mem,vcpu,volumes}`)
- `deployNodes{hostname,sshUser}`, `proxy`, `plugins` (when enabled), `catalog` (roles/bundles/presets + registries)

## ui.json

`navigation` (Dashboard, Hosts, Journal, Terminal, Deploy, VMs when hasVms, NixOS, Git, GitHub, Monitoring, Network, Settings + `lucy.nixfleet.ui` extras), `dashboard.widgets` (one host-summary per host), `featureFlags` (terminal/files/containers/tailscale/proxy), `rbac` (default `admin * *`).

## API (typed Go, no shell strings)

```
GET /api/v1/hosts
GET /api/v1/hosts/:host/health      → healthy|degraded|critical|unknown + failedUnits
GET /api/v1/hosts/:host/resources   → /proc (cpu/ram/swap/load/disk/procs)
GET /api/v1/hosts/:host/network     → ip -j addr/link
GET /api/v1/hosts/:host/vms         → configured+runtime (systemctl is-active microvm@<name>)
GET /api/v1/hosts/:host/systemd/failed → systemctl --failed
```

`404` for unknown host/VM, `503` for non-local host (M1 is mireo-only). Frontend: `HostOverview`, `VMTable` (Name|IP|State|vCPU|RAM|Health|Ports), `SystemdFailed`.

## Module `lucy.nixfleet.*`

`enable`, `role=api|agent|cli` (used for apiHost/plugins, but services are **package-gated**: `api.package`→api service, `agent.package`→agent service), `api{package,port=8443,artifactsDir,webDir=null for now,proxy}`, `agent{package,endpoint=wss://nixfleet.lan:8443/api/v1/ws,tokenFile,plugins=[systemd journal metrics],filesRoots,terminalUser=lucy}`, `ui{navigation,dashboardWidgets,pages}`, `rbac`.
Services: `nixfleet-api` (DynamicUser, StateDir), `nixfleet-agent` (30s heartbeat). Firewall: br0 allows 8443.

## Roadmap

M0 scaffolding ✓ · **M1 mireo control plane ✓** · M1-full WS/auth/SQLite+meta · M2 systemd/terminal/files · M3 deploy/rollback/GC/git · M4 microvm/podman/network/proxy · M5 tailscale/RBAC/2FA/hardening. Open questions: repo checkout location, serial console, manifest CI cadence, node_exporter gap, dashboard granularity.
