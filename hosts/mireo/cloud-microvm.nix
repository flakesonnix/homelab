# Cloud microVM: Nextcloud
# Personal cloud storage and collaboration.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "cloud";
      ip = (import ./vm-ips.nix).nextcloud;
      mem = 2048;
      vcpu = 4;
      tcpPorts = [22 443];
      volumes = [
        {
          image = "nextcloud-data.img";
          mountPoint = "/data/nextcloud";
          size = 8192;
          user = "nextcloud";
          group = "nextcloud";
        }
      ];
      shares = [
        {
          tag = "cloud-secrets";
          source = "/run/secrets/cloud";
          mountPoint = "/run/secrets/cloud";
          readOnly = true;
        }
        {
          tag = "photos";
          source = "/data/photos";
          mountPoint = "/data/photos";
          readOnly = false;
        }
      ];
      tmpfiles = [
        "d /data/nextcloud 0750 nextcloud nextcloud - -"
      ];
      config = {
        imports = [(import ../../modules/nixos/nextcloud.nix)];
        lucy.services.nextcloud = {
          enable = true;
          host = "nextcloud.home.arpa";
          dataDir = "/data/nextcloud";
          databaseName = "nextcloud";
          databaseUser = "nextcloud";
          databasePasswordSecret = "database/nextcloud";
          adminPasswordSecret = "database/nextcloud";
        };
      };
    })
  ];
}
