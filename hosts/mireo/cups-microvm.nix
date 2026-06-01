{pkgs, ...}: {
  systemd.network.networks."29-lan-microvm-cups" = {
    matchConfig.Name = "vm-cups";
    networkConfig.Bridge = "br0";
  };

  # Give the microvm QEMU process access to the Epson ET-2860 (04b8:11c8)
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="04b8", ATTR{idProduct}=="11c8", GROUP="kvm", MODE="0660"
  '';

  microvm.autostart = ["cups"];

  microvm.vms.cups = {
    autostart = true;
    config = {
      imports = [
        (import ./microvm-base.nix {
          ip = "10.8.0.6";
          mac = "02:00:00:10:08:06";
          interfaceId = "vm-cups";
        })
      ];

      networking.hostName = "cups";
      networking.firewall.allowedTCPPorts = [22 631];
      networking.firewall.allowedUDPPorts = [631 5353];

      microvm.mem = 512;
      microvm.vcpu = 1;
      microvm.qemu.package = pkgs.qemu_full;
      microvm.volumes = [
        {
          image = "cups-etc.img";
          mountPoint = "/etc/cups";
          size = 256;
        }
      ];
      # Epson ET-2860 USB passthrough (04b8:11c8)
      microvm.qemu.extraArgs = [
        "-device"
        "qemu-xhci,id=xhci"
        "-device"
        "usb-host,vendorid=0x04b8,productid=0x11c8"
      ];

      services.printing = {
        enable = true;
        listenAddresses = ["*:631"];
        browsing = true;
        defaultShared = true;
        allowFrom = ["all"];
        drivers = [pkgs.epson-escpr2];
        extraConf = ''
          <Location />
            Allow @LOCAL
            Order allow,deny
          </Location>
          <Location /admin>
            Allow @LOCAL
            Order allow,deny
          </Location>
          <Location /admin/conf>
            Allow @LOCAL
            Order allow,deny
          </Location>
        '';
      };

      # Device URI: verify with `lpinfo -v` after deploy if printer not found
      # Model: verify with `lpinfo -m | grep ET-2860` after deploy
      hardware.printers.ensureDefaultPrinter = "Epson-ET-2860";
      hardware.printers.ensurePrinters = [
        {
          name = "Epson-ET-2860";
          location = "mireo";
          deviceUri = "usb://EPSON/ET-2860%20Series";
          model = "epson-inkjet-printer-escpr2/Epson-ET-2860_Series-epson-escpr2-en.ppd";
          ppdOptions.PageSize = "A4";
        }
      ];

      # Avahi: advertise printer via mDNS (IPP) for zero-config discovery
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          userServices = true;
        };
      };
    };
  };
}
