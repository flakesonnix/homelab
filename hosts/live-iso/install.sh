#!/usr/bin/env bash
set -euo pipefail

FLAKE_SRC="/etc/nixos/dotfiles"
if [ ! -d "$FLAKE_SRC" ]; then
  FLAKE_SRC="$(pwd)"
fi

echo "=== Lucy dotfiles installer (live ISO) ==="
echo "Flake: $FLAKE_SRC"
echo "Hosts: $(nix eval --raw "$FLAKE_SRC#nixosConfigurations" --apply 'x: builtins.concatStringsSep ", " (builtins.attrNames x)' 2>/dev/null || echo "x270, mireo, live")"
echo ""

read -rp "Target host [x270/mireo/live/custom]: " HOST
HOST=${HOST:-x270}
if [ "$HOST" = "custom" ]; then
  read -rp "Custom flake attr (e.g. x270): " HOST
fi

echo ""
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL | cat
echo ""
read -rp "Disk to install to (e.g. /dev/nvme0n1 or /dev/sda) or 'manual' if already partitioned: " DISK

if [ "$DISK" != "manual" ]; then
  echo "This WILL WIPE $DISK — Ctrl+C to abort, Enter to continue"
  read -r
  echo "Partitioning $DISK (GPT, 512M EFI + rest ext4)..."
  parted -s "$DISK" mklabel gpt mkpart ESP fat32 1MiB 512MiB set 1 esp on mkpart primary ext4 512MiB 100%
  EFI_PART="${DISK}1"
  ROOT_PART="${DISK}2"
  # NVMe p1 vs sda1 handling: if DISK is /dev/nvme0n1, parts are /dev/nvme0n1p1
  if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
  fi
  mkfs.fat -F32 -n BOOT "$EFI_PART"
  mkfs.ext4 -F -L nixos "$ROOT_PART"
  mount "$ROOT_PART" /mnt
  mkdir -p /mnt/boot
  mount "$EFI_PART" /mnt/boot
else
  echo "Assuming /mnt already mounted. Check:"
  lsblk -o NAME,MOUNTPOINT | cat
  mount | grep /mnt | cat
  read -rp "Continue with /mnt as is? [y/N]: " yn
  [[ "$yn" == "y" ]] || exit 1
fi

echo "Generating hardware-configuration.nix..."
nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw.nix
echo "Created /tmp/hw.nix — review, then it will be copied if you use custom host."

echo ""
echo "Installing NixOS flake $FLAKE_SRC#$HOST to /mnt..."
nixos-install --flake "$FLAKE_SRC#$HOST" --no-root-passwd --impure || {
  echo "nixos-install failed — try: nixos-install --flake $FLAKE_SRC#$HOST --impure --no-root-passwd -v"
  exit 1
}

echo ""
echo "Setting passwords (nixos/lucy/root = nixos, change after reboot)..."
for u in nixos lucy root; do
  echo "nixos" | nixos-enter --root /mnt -c "echo $u:nixos | chpasswd" || true
done

echo ""
echo "Done. Flake copied to /mnt/etc/nixos/dotfiles for next rebuild."
mkdir -p /mnt/etc/nixos
if [ -d "$FLAKE_SRC/.git" ]; then
  cp -a "$FLAKE_SRC" /mnt/etc/nixos/dotfiles
else
  cp -a "$FLAKE_SRC" /mnt/etc/nixos/dotfiles
fi

echo "Unmount? [y/N]: "
read -r yn
if [[ "$yn" == "y" ]]; then
  umount -R /mnt || true
fi

echo "Reboot and remove ISO. TTY: login nixos, Niri: greetd → niri-session (lucy/nixos)."
