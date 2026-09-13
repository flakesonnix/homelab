# Host-specific settings for nyagate (remote QEMU server, db210.org).
# Network + bootloader values imported from new/configuration.nix.
{lib, ...}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@nyagate";

  networking.hostName = "nyagate";

  # Static IPv4 (Hetzner-style /32 + gateway route).
  networking.useDHCP = false;
  networking.interfaces.eth0 = {
    ipv4.addresses = [
      {
        address = "188.220.148.24";
        prefixLength = 32;
      }
    ];
  };
  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "eth0";
  };
  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  # BIOS boot on /dev/vda (QEMU guest, no EFI).
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  services.openssh.enable = true;

  # Installed as 26.11 — keep in sync with the initial install.
  system.stateVersion = "26.11";

  lucy.topology = {
    # Valid devices.* icons: cloud, cloud-server, desktop, laptop, nixos, router, switch.
    icon = "devices.cloud-server";
    hardware.info = "QEMU VM · db210.org";
  };
}
