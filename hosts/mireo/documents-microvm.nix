# Documents microVM: Paperless
# Document scanning and management.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "documents";
      ip = (import ./vm-ips.nix).paperless;
      mem = 1024;
      vcpu = 2;
      tcpPorts = [22 80];
      volumes = [
        {
          image = "paperless-data.img";
          mountPoint = "/data/paperless";
          size = 2048;
          user = "paperless";
          group = "paperless";
        }
      ];
      # NOTE: no documents-secrets share — /run/secrets/documents doesn't
      # exist on the host yet (no sops secrets). A virtiofs share with a
      # missing source fails QEMU at start and breaks the whole switch
      # (2026-10-04 incident). Land host sops secrets first, then re-add
      # the share in that commit (and drop "documents" from secretlessVMs
      # in tests/default.nix).
      tmpfiles = [
        "d /data/paperless 0750 paperless paperless - -"
      ];
      config = {
        imports = [(import ../../modules/nixos/paperless.nix)];
        lucy.services.paperless = {
          enable = true;
          dataDir = "/data/paperless";
          databaseName = "paperless";
          databaseUser = "paperless";
          databasePasswordSecret = "database/paperless";
        };
        # Add pci-setup script to satisfy ConditionPathExists in microvm-pci-devices@.service
        systemd.services."pci-setup-documents" = {
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/true";
          };
        };
      };
    })
  ];
}
