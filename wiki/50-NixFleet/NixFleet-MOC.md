---
aliases: [NixFleet, Control plane]
tags: [moc, nixfleet]
type: moc
---

# NixFleet overview (M1, Sep 2026)

[[Home|← Home]] · Source `nixfleet/docs/architecture.md`, `docs/data-model.md#NixFleet`, `modules/nixos/nixfleet.nix`.

> **Nix first:** everything declarative → Nix artifact, runtime → Go, presentation → React. Go/React never invent structure.

- API + agent run on [[10-Hosts/mireo|mireo]] `:8443`, frontend widgets `HostOverview`+`VMTable`+`SystemdFailed`, pages `/vms` `/network` (dark dense monospace).
- Manifest/UI: pure Nix → `nixfleet/artifacts/{manifest,ui}.json` → committed by CI → API serves them verbatim (`GET /api/v1/meta`).
- No WebSocket/auth/SQLite yet — observability first. M1-full: agent WS protocol + full multi-host support.

Next: [[50-NixFleet/Manifest-API|Manifest & API]] — endpoints, types, options, roadmap.
CLI: `nix run .#nixfleet` (`status`, `health`), `nix run .#nixfleet-manifest`.
