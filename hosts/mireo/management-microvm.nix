# Management microVM: NetBox + LibreNMS
# Network inventory and monitoring.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "management";
      ip = (import ./vm-ips.nix).netbox;
      mem = 1024;
      vcpu = 2;
      tcpPorts = [22 443];
      volumes = [
        {
          image = "netbox-data.img";
          mountPoint = "/data/netbox";
          size = 1024;
          user = "netbox";
          group = "netbox";
        }
        {
          image = "librenms-data.img";
          mountPoint = "/data/librenms";
          size = 1024;
          user = "librenms";
          group = "librenms";
        }
      ];
      shares = [
        {
          tag = "management-secrets";
          source = "/run/secrets/management";
          mountPoint = "/run/secrets/management";
          readOnly = true;
        }
      ];
      tmpfiles = [
        "d /data/netbox 0750 netbox netbox - -"
        "d /data/librenms 0750 librenms librenms - -"
      ];
      config = {
        imports = [
          (import ../../modules/nixos/netbox.nix)
          (import ../../modules/nixos/librenms.nix)
        ];
        lucy.services.netbox = {
          enable = true;
          dataDir = "/data/netbox";
          databaseName = "netbox";
          databaseUser = "netbox";
          databasePasswordSecret = "database/netbox";
        };
        lucy.services.librenms = {
          enable = true;
          dataDir = "/data/librenms";
          databaseName = "librenms";
          databaseUser = "librenms";
          databasePasswordSecret = "database/librenms";
        };
      };
    })
  ];
}
