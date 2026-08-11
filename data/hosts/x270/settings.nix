{lib, ...}: {
  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@x270";

  networking.hostName = "x270";
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

  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "console=tty1"
  ];

  niri.users = ["lucy"];

  lucy.topology = {
    icon = "devices.laptop";
    hardware.info = "Lenovo ThinkPad X270 · i7-7600U";
  };

  hq.deskflow.enable = true;
}
