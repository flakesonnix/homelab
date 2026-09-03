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

## Purr 🐱

Purr is a little language I'm experimenting with.

The idea is simple:

```text
Purr → Nix
```

I don't really like writing everything directly in Nix, so I'm experimenting with a language that can describe infrastructure in a way that makes more sense to me.

The compiler is written in Zig.

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
