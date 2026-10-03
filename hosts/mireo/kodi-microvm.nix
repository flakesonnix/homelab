# Kodi headless music box (microVM on br0, behind Caddy on mireo).
# YouTube / SoundCloud / Jellyfin -> Behringer Xenyx 302USB
# (TI PCM2902, USB 08bb:2902) via QEMU USB passthrough from the host.
# Control: web UI http://kodi.home.arpa, Firefox "Play to Kodi",
# Android Kore / Yatse. Implementation: modules/nixos/kodi-box.nix.
# If the mixer is ever replaced, adjust vendorid/productid below
# (see `lsusb`) AND the host udev rule in data/hosts/mireo/settings.nix.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "kodi";
      ip = (import ./vm-ips.nix).kodi;
      mem = 1536;
      vcpu = 2;
      tcpPorts = [22 8080 9090];
      udpPorts = [9777 5353];
      shares = [
        {
          tag = "jellyfin-media";
          source = "/data/Jellyfin";
          mountPoint = "/media";
          readOnly = true;
        }
      ];
      volumes = [
        {
          image = "kodi-data.img";
          mountPoint = "/var/lib/kodi";
          size = 2048;
          user = "kodi";
          group = "kodi";
        }
      ];
      config = {
        imports = [(import ../../modules/nixos/kodi-box.nix)];
        lucy.services."kodi-box" = {
          enable = true;
          jellyfinHost = (import ./vm-ips.nix).jellyfin;
        };
        microvm.devices = [
          {
            bus = "usb";
            path = "vendorid=0x08bb,productid=0x2902";
          }
        ];
      };
    })
  ];
}
