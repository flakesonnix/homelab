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
      # NOTE: no media-secrets share — the per-VM host secrets dir doesn't
      # exist yet (no sops secrets). A virtiofs share with a missing
      # source fails QEMU at start and breaks the whole switch (2026-10-04
      # incident). Land host sops secrets first, then re-add the share in
      # that commit (and drop "media" from secretlessVMs in
      # tests/default.nix).
      shares = [
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
