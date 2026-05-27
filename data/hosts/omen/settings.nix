{lib, ...}: {
  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@omen";

  networking.hostName = "omen";
  networking.networkmanager.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };
  services.blueman.enable = true;

  boot.initrd.availableKernelModules = ["r8169"];
  boot.kernelParams = [
    "tpm.disable=1"
    "nvme_core.default_ps_max_latency_us=0"
    "console=tty1"
  ];

  niri.users = ["lucy"];

  hq.deskflow = {
    enable = true;
    role = "server";
    screenLayout = {
      x61 = { right = "omen"; };
      omen = { left = "x61"; right = "p50"; };
      p50 = { left = "omen"; };
    };
  };
}
