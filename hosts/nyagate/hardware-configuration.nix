# Imported from new/hardware-configuration.nix (nixos-generate-config on db210.org).
# Do not modify! Regenerate with ‘nixos-generate-config’ on the host instead.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "virtio_blk"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/4a790d5d-57dd-4d92-af5a-8b2992d297f7";
    fsType = "ext4";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
