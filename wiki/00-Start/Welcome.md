---
aliases: [Welcome]
tags: [start, guide]
type: guide
---

# Welcome

[[Home|← Home]]

This vault is Obsidian-first documentation for this repo (`flake.nix`, `hosts/`, `modules/`, `data/`, `nixfleet/`).

## How to use it

1. Start at [[Home|Home]], then branch out via the MOCs (`*-MOC.md`).
2. Every host page has frontmatter (`type: host`, `ip`, `roles`) → for [[99-Meta/Dataview-Queries|Dataview]].
3. Every module page has `type: module`, `namespace:` → instantly recognizable in the graph.
4. Guides are step-by-step and copy-paste ready, with `bash` blocks.
5. The original Markdown files under `docs/` remain the source for details — linked from here as `../docs/*.md` or repo paths.

## Conventions in this vault

- `[[Wikilinks]]` for internal navigation, **no** Markdown links internally.
- Tags: `#host` `#module` `#guide` `#network` `#nixfleet` `#nixos` `#secret` `#todo`
- Frontmatter always: `aliases`, `tags`, `type`
- Code paths in `` `backticks` ``, e.g. `data/hosts/x270/settings.nix`, `flake.nix:193`
- Status box at the top of host pages: role, IP, deploy command.

## Where is the vault?

Repo root `wiki/` is the vault root (with `wiki/.obsidian/`). In Obsidian: **Open folder as vault → select `wiki/`**.

> No publish, no sync plugin preconfigured. `.obsidian/` is committed so graph colors + templates are the same for everyone. Safe to push — the vault contains no secrets.

## Next

- [[00-Start/Quickstart|Quickstart]] — rebuild in 5 min
- [[00-Start/Just-Cheatsheet|Just cheatsheet]]
- [[00-Start/Glossary|Glossary]]
