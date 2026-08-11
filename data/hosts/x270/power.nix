{
  lucy.serialGetty.disabled = ["ttyS0" "ttyS1" "ttyS2" "ttyS3"];

  services.thermald.enable = true;

  powerManagement.enable = true;

  # Hibernate to the 16G swapfile on the encrypted root (≥ 15G RAM, and
  # encrypted unlike the plain swap partition). resume_offset = first
  # extent of /swapfile in 512-byte sectors (filefrag: 262725632 * 8).
  # The 8.8G partition swap stays as plain swap space.
  swapDevices = [{device = "/swapfile";}];
  boot.resumeDevice = "/dev/mapper/luks-90b17531-753e-4576-a453-a7d81be1d09e";

  # Note: settings/power/services are merged with lib.recursiveUpdate, so
  # boot.kernelParams must live in exactly one of them.
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "console=tty1"
    "resume_offset=2101805056"
  ];

  # Lid close: suspend, then hibernate after 30 min (only on battery, so
  # sleep-in-bag doesn't drain the battery; on AC just suspend).
  systemd.sleep.settings.Sleep.HibernateDelaySec = "1800";
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
    HandleSuspendKey = "suspend";
    HandlePowerKey = "poweroff";
  };
}
