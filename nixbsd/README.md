# NixBSD on the ThinkPad P53

Experimental FreeBSD-based system, separate from the Linux flake and its lockfile.
The NixBSD revision and its own nixpkgs are pinned; do not make its nixpkgs follow
the main NixOS input. Existing NixOS modules, Home Manager, Lanzaboote and the
Linux NVIDIA/Niri configuration are not imported.

## Disk Safety

The approved installation target is the **Samsung 970 EVO Plus 2 TB**. At the
initial inspection it was `/dev/nvme0n1`, with an EFI partition and a LUKS
partition. Erasing its contents has been approved.

The **Samsung 990 PRO 2 TB** contains NixOS and must not be modified. At the
initial inspection it was `/dev/nvme1n1`, including the mounted `/boot`, root and
swap partitions. Device numbering can change across boots and operating systems;
identify the disks again by model and serial before any write.

Nothing in this flake partitions, formats or writes a physical disk. No installer
command should be pointed at a guessed FreeBSD `nda`/`nvd` device. Keep the NixBSD
EFI partition on the target SSD, separate from the NixOS EFI partition. Disconnect
the NixOS SSD during installation if practical.

## Build And Test From NixOS

Run these commands from the dotfiles repository root. The explicit `path:` input
also works before the new subflake files have been added to Git.

```sh
nix flake check path:./nixbsd
nix build path:./nixbsd#image --out-link nixbsd/result-image --max-jobs 4 --cores 3
```

Builds use the normal host caches only, not an automatically trusted third-party
NixBSD cache. A first cross-build can take hours and require tens of GiB.
The check validates configuration invariants; it does not build or boot the image.

The image is `nixbsd/result-image/nixbsd-disk-image.qcow2`, a complete GPT disk
image with UFS root and a FAT EFI partition, not an installer ISO. The VM creates
a writable copy and EFI-variable file in the current working directory by
default. Keep that state outside the repository when starting the test VM:

```sh
mkdir -p /tmp/opencode/nixbsd-p53
NIX_DISK_IMAGE=/tmp/opencode/nixbsd-p53/root.qcow2 \
  NIX_EFI_VARS=/tmp/opencode/nixbsd-p53/efi.fd \
  nix run path:./nixbsd
```

The VM has no physical disk passed through. It tests the FreeBSD console boot,
not the P53's actual graphics, wireless, suspend or storage hardware.

## First Boot

**Initially, root can log in at the local console without a password. SSH is
disabled, and lucy's password login is locked.** Before normal use, switch to a
text console, log in as `root`, and set both passwords interactively:

```sh
passwd root
passwd lucy
```

Then log in as `lucy`. Passwords persist because `users.mutableUsers` is
enabled. Never put a real password into the flake or Nix store. Passwords set in a
VM copy do not change the original immutable image or a separately booted USB.
For an actual installation, set the installed system's passwords before its
first normal boot.

Start with Ethernet. This first configuration is console-only: the pinned
`xfce4-session` package is marked Linux-only, so the upstream graphical example
cannot currently be evaluated without further package work. Intel UHD 630 would
need FreeBSD's `i915kms` and DRM firmware for an accelerated desktop; those are
not enabled yet. NVIDIA hybrid graphics and AX200 wireless are not validated.
There is no Linux PRIME configuration. Secure Boot was disabled during inspection;
the image uses FreeBSD's UEFI loader, not a Lanzaboote-signed Linux kernel.

## Installation Boundary

Upstream's current bare-metal route is a writable USB image followed by manual
partitioning and `nixos-install` from the booted NixBSD system. There is no merged
installer ISO or automatic hardware configuration generator at the pinned
revision. A USB hardware test must come before changing the NVMe.

After a successful VM test, a regular raw image file can be produced safely:

```sh
qemu-img convert -f qcow2 -O raw \
  nixbsd/result-image/nixbsd-disk-image.qcow2 \
  /tmp/opencode/nixbsd-p53.img
```

This command writes a file, not a disk. Writing it onto a USB or NVMe replaces
that device's partition layout. It is not an installation into free space. The
example root is only 32 GiB and **unencrypted**; cloning it does not automatically
use the entire SSD. The current image puts the EFI partition after the root
partition, so expanding the image alone is not a full-disk partitioning solution.
Choose the final target layout explicitly during installation.

From NixBSD, the host configuration is available as
`nixosConfigurations.p53` in this subflake, without forcing a Linux build platform
on subsequent native rebuilds. Remove the USB before booting the installed system
to avoid duplicate filesystem labels. Use the firmware boot picker to select the
NixBSD SSD without replacing the existing NixOS bootloader.

References:

- [NixBSD upstream](https://github.com/nix-community/nixbsd)
- [Pinned source](https://github.com/nix-community/nixbsd/tree/8cf417b68b3426f6f4a3fcafdaf2fa3dfde0195d)
- [Maintainer installation notes](https://github.com/nix-community/nixbsd/issues/26#issuecomment-1995422435)
- [Installer ISO work, not part of this pin](https://github.com/nix-community/nixbsd/pull/59)
