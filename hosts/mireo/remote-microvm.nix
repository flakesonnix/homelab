# Remote microVM: RustDesk
# Remote desktop server.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "remote";
      ip = (import ./vm-ips.nix).rustdesk;
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 21115 21116 21118 21119 21121 21122 21123 21124];
      volumes = [
        {
          image = "rustdesk-data.img";
          mountPoint = "/data/rustdesk";
          size = 512;
          user = "rustdesk";
          group = "rustdesk";
        }
      ];
      config = {
        imports = [(import ../../modules/nixos/rustdesk.nix)];
        lucy.services.rustdesk = {
          enable = true;
          dataDir = "/data/rustdesk";
        };
      };
    })
  ];
}
