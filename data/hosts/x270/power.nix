{
  lucy.serialGetty.disabled = ["ttyS0" "ttyS1" "ttyS2" "ttyS3"];

  services.thermald.enable = true;

  powerManagement.enable = true;

  # Resume from hibernate on the 8.8G swap partition (nvme0n1p3).
  boot.resumeDevice = "/dev/disk/by-uuid/fcd9218a-b52f-4550-be7f-fab90b56d504";

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
