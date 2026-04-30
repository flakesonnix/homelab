{lib, ...}: {
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  networking.hostName = "omen";
  networking.networkmanager.enable = true;

  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["r8169"];
  boot.kernelParams = [
    "tpm.disable=1"
    "nvme_core.default_ps_max_latency_us=0"
    "console=tty1"
  ];

  nix.settings.require-sigs = false;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  security.run0-sudo-shim.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";

  hardware.nvidia.powerManagement.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
