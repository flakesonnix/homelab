{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ata_piix" "ahci" "firewire_ohci" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/mapper/x61";
    fsType = "ext4";
  };

  boot.initrd.luks.devices."x61".device = "/dev/disk/by-uuid/f884890e-a4e6-4f5e-9f3f-464c9ba149f7";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8c131208-cfcb-4e6f-b422-a4bcebcea3ba";
    fsType = "ext4";
  };

  swapDevices = [{device = "/dev/disk/by-uuid/bdf8c7cc-ea36-47e4-a606-4555aa83afba";}];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
