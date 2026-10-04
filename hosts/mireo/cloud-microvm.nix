# Cloud microVM: Nextcloud
# Personal cloud storage and collaboration.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "cloud";
      ip = (import ./vm-ips.nix).nextcloud;
      mem = 2304; # NB: never exactly 2048 (QEMU hangs, microvm.nix#171)
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
      # NOTE: no cloud-secrets share — /run/secrets/cloud doesn't exist on
      # the host yet (no sops secrets). A virtiofs share with a missing
      # source fails QEMU at start and breaks the whole switch (2026-10-04
      # incident). Land host sops secrets first, then re-add the share in
      # that commit (and drop "cloud" from secretlessVMs in
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
        # Add pci-setup script to satisfy ConditionPathExists in microvm-pci-devices@.service
        systemd.services."pci-setup-cloud" = {
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/true";
          };
        };
      };
    })
  ];
}
