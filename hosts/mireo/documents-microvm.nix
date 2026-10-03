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
      shares = [
        {
          tag = "documents-secrets";
          source = "/run/secrets/documents";
          mountPoint = "/run/secrets/documents";
          readOnly = true;
        }
      ];
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
      };
    })
  ];
}
