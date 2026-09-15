{lib, ...}: {
  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@x270";

  networking.hostName = "x270";
  networking.networkmanager.enable = true;

  # Time sync: own NTP VM first (single source via vm-ips.nix), public
  # pools as fallback for roaming (timesyncd tries in order). mireo host
  # and microVMs intentionally keep upstream defaults (no guest-boot
  # dependency for the router).
  networking.timeServers = [
    (import ../../../hosts/mireo/vm-ips.nix).ntp
    "0.nixos.pool.ntp.org"
    "1.nixos.pool.ntp.org"
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };
  services.blueman.enable = true;

  niri.users = ["lucy"];

  lucy.topology = {
    icon = "devices.laptop";
    hardware.info = "Lenovo ThinkPad X270 · i7-7600U";
  };

  hq.deskflow.enable = true;

  # Workaround for libvirtd TPM failure on recent NixOS (tpmrm0 missing, exit 243).
  # Local daemon aus, Client bleibt an für remote mireo:
  # qemu+ssh://root@10.8.0.1/system (programs.virt-manager aus base.nix).
  virtualisation.libvirtd.enable = lib.mkForce false;
  programs.virt-manager.enable = true;
}
