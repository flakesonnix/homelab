{lib, ...}: {
  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  networking.hostName = "p50";
  networking.networkmanager.enable = true;

  lucy.gnome.enable = true;
  programs.niri.enable = lib.mkForce false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.enable = false;
  boot.initrd.availableKernelModules = ["e1000e"];
  boot.kernelParams = [
    "console=tty1"
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = "lucy";
  };

  nix.settings.substituters = lib.mkBefore ["http://omen:5000"];

  hardware.nvidia.powerManagement.enable = lib.mkForce false;

  hq.deskflow = {
    enable = true;
    role = "client";
    serverAddress = "omen";
  };

  topology.self = {
    icon = "devices.desktop";
    hardware.info = "ThinkPad P50 · NVIDIA 535";
  };
}
