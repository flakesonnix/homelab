# Communication microVM: Matrix + ntfy
# Messaging and notification service.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "communication";
      ip = (import ./vm-ips.nix).matrix;
      # interface id must stay <=15 chars (Linux IFNAMSIZ)
      interfaceId = "vm-comm";
      mem = 2304; # NB: never exactly 2048 (QEMU hangs, microvm.nix#171)
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
      # NOTE: no communication-secrets share — /run/secrets/communication
      # doesn't exist on the host yet (no sops secrets). A virtiofs share
      # with a missing source fails QEMU at start and breaks the whole
      # switch (2026-10-04 incident). Land host sops secrets first, then
      # re-add the share in that commit (and drop "communication" from
      # secretlessVMs in tests/default.nix).
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
