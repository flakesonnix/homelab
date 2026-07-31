{pkgs, ...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "cups";
      ip = "10.8.0.6";
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 631];
      udpPorts = [631 5353];
      volumes = [
        {
          image = "cups-etc.img";
          mountPoint = "/etc/cups";
          size = 256;
        }
      ];
      config = {
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
          {
            name = "Lexmark";
            location = "mireo";
            deviceUri = "ipp://10.8.0.197/ipp/print";
            model = "everywhere";
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
    })
  ];
}
