# Communication microVM: Matrix + ntfy
# Messaging and notification service.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "communication";
      ip = (import ./vm-ips.nix).matrix;
      # interface id must stay <=15 chars (Linux IFNAMSIZ)
      interfaceId = "vm-comm";
      mem = 2048;
      vcpu = 2;
      tcpPorts = [22 443 8448];
      volumes = [
        {
          image = "matrix-data.img";
          mountPoint = "/data/matrix";
          size = 4096;
          user = "matrix";
          group = "matrix";
        }
        {
          image = "ntfy-data.img";
          mountPoint = "/data/ntfy";
          size = 1024;
          user = "ntfy";
          group = "ntfy";
        }
      ];
      shares = [
        {
          tag = "communication-secrets";
          source = "/run/secrets/communication";
          mountPoint = "/run/secrets/communication";
          readOnly = true;
        }
      ];
      tmpfiles = [
        "d /data/matrix 0750 matrix matrix - -"
        "d /data/ntfy 0750 ntfy ntfy - -"
      ];
      config = {
        imports = [
          (import ../../modules/nixos/matrix.nix)
          (import ../../modules/nixos/ntfy.nix)
        ];
        lucy.services.matrix = {
          enable = true;
          dataDir = "/data/matrix";
        };
        lucy.services.ntfy = {
          enable = true;
          dataDir = "/data/ntfy";
        };
        # Add pci-setup script to satisfy ConditionPathExists in microvm-pci-devices@.service
        systemd.services."pci-setup-communication" = {
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/true";
          };
        };
      };
    })
  ];
}
