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
        imports = [
          ../../modules/nixos/cups.nix
        ];
        lucy.cups = {
          enable = true;
          printers = [
            {
              name = "Lexmark-MX410";
              location = "mireo";
              deviceUri = "ipp://10.8.0.197/ipp/print";
              model = "everywhere";
              ppdOptions.PageSize = "A4";
              isDefault = true;
            }
          ];
        };
      };
    })
  ];
}
