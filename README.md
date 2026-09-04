# 🐾 NixOS Homelab

My NixOS setup.

It started as some dotfiles and somehow turned into a small framework for managing my machines.
At this point I'm mostly trying to keep it from becoming worse.

## What's in here?

* ❄️ NixOS + Home Manager
* 🖥️ `x270` — my desktop/laptop
* 🏠 `mireo` — my home server/router
* 📦 roles, bundles and presets for composing hosts
* 🔐 sops-nix / age for secrets
* 🌐 networking, NFS, PXE, microVMs
* 🐾 NixFleet — a small management/monitoring thing I'm building
* 😺 Purr — a programming language/compiler experiment that generates Nix

The framework stuff lives mostly under `lib/` and `data/`.

## Hosts

### x270

ThinkPad X270.

Desktop setup, Niri, gaming stuff, Wayland things and the usual amount of configuration required to make Linux do what I want.

### mireo

My little home server/router.

It handles networking and hosts a bunch of services and microVMs.

## Structure

```text
data/
├── hosts/
├── roles/
├── bundles/
├── presets/
└── packages/

lib/
└── framework/

modules/
├── nixos/
└── home/

hosts/
├── x270/
└── mireo/

home/
└── lucy/

nixfleet/
└── ...

purr/
└── ...
```

The idea is that hosts mostly describe **what they are**, rather than containing a giant pile of unrelated NixOS options.

## NixFleet

NixFleet is my attempt at having a small UI/API for the machines managed by this flake.

Right now it's mostly about seeing what's happening:

* hosts
* resources
* networking
* VMs
* failed systemd units

Deployment and terminal access can come later.

## Purr 🐱 — Nix DSL compiler (Zig)

Purr is a declarative systems language that compiles to Nix. It describes **what a host is** (roles, bundles, presets, packages) rather than raw NixOS options, with strict diagnostics before Nix eval.

```text
.purr → lexer → parser → AST → resolver → semantic → Nix → NixOS
```

**Compiler:** Zig 0.16, `purr/` has its own flake (`nix develop` → `zig build`, `zig build test`). Also built from root flake via `purr`.

**CLI:**

```bash
purr check file.purr                # parse + semantic (no Nix)
purr compile file.purr --out out.nix # generate deterministic Nix
# examples
purr check purr/examples/minimal.purr
purr compile purr/examples/hosts/x270.purr --out /tmp/x270.nix
bash purr/tests/e2e.sh              # .purr → Nix → alejandra + import edge cases
```

**Language (v0.1):** `role`, `host`, `bundle`, `preset`, `package`, `import "path.purr";`, `nix { ... }` escape, `string`/`int`/`bool`/`list`, `//`/`/* */` comments, `;` terminated.

```purr
import "roles/desktop.purr";

role desktop {
    description = "Desktop";
    host { presets = ["gaming-base"]; tags = ["desktop"]; }
    home { bundles = ["desktop"]; }
}
host x270 { use desktop; package "git"; preset gaming-performance; }
```

**Diagnostics:** `purr error[E042]: unknown role "gamign" — did you mean "gaming"?` with file:line:col + context + help (E001 parse, E002 lex, E010 duplicate, E042/E043/E044 unknown).

**Status:** v0.1 on branch `meow` — 13 unit+golden tests + E2E (`cyclic/duplicate/transitive/missing` imports, `alejandra` syntax). See `docs/purr/design.md` and `purr/examples/`.

## Why?

Because apparently `configuration.nix` wasn't complicated enough.

And because I wanted to see how far I could push Nix before deciding I should probably have written a compiler instead.

## Status

This is **my actual homelab**, not a polished framework.

Things will change.
Some parts are over-engineered.
Some parts are probably bad ideas.

If something looks weird, there's a good chance there's a reason — or I just haven't fixed it yet.

🐾
