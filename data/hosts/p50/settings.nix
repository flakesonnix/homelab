{lib, ...}: {
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  networking.hostName = "p50";
  networking.hosts."10.8.0.176" = ["omen"];
  networking.hosts."10.8.0.122" = ["p50"];
  networking.hosts."10.8.0.163" = ["x61"];
  networking.hosts."10.8.0.1" = ["mireo"];
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["e1000e"];
  boot.kernelParams = [
    "console=tty1"
  ];

  nix.settings.require-sigs = false;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  security.polkit.persistentAuthentication = true;
  security.run0-sudo-shim.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";

  hardware.nvidia.powerManagement.enable = lib.mkForce false;

  fileSystems."/mnt/mireo/data" = {
    device = "10.8.0.1:/data";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=600"];
  };

  system.stateVersion = "25.11";
}
