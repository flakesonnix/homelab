# Media microVM: Immich
# Photo management and AI tagging.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "media";
      ip = (import ./vm-ips.nix).immich;
      mem = 4096;
      vcpu = 4;
      tcpPorts = [22 443];
      volumes = [
        {
          image = "immich-data.img";
          mountPoint = "/data/immich";
          size = 8192;
          user = "immich";
          group = "immich";
        }
      ];
      shares = [
        {
          tag = "media-secrets";
          source = "/run/secrets/media";
          mountPoint = "/run/secrets/media";
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
        "d /data/immich 0750 immich immich - -"
      ];
      config = {
        imports = [(import ../../modules/nixos/immich.nix)];
        lucy.services.immich = {
          enable = true;
          dataDir = "/data/immich";
          databaseName = "immich";
          databaseUser = "immich";
          databasePasswordSecret = "database/immich";
        };
      };
    })
  ];
}
