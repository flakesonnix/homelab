# Sync microVM: Syncthing
# File synchronization across devices.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "sync";
      ip = (import ./vm-ips.nix).syncthing;
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 8384 22000];
      volumes = [
        {
          image = "syncthing-data.img";
          mountPoint = "/data/syncthing";
          size = 1024;
          user = "syncthing";
          group = "syncthing";
        }
      ];
      shares = [
        {
          tag = "sync-secrets";
          source = "/run/secrets/sync";
          mountPoint = "/run/secrets/sync";
          readOnly = true;
        }
      ];
      tmpfiles = [
        "d /data/syncthing 0750 syncthing syncthing - -"
      ];
      config = {
        imports = [(import ../../modules/nixos/syncthing.nix)];
        lucy.services.syncthing = {
          enable = true;
          dataDir = "/data/syncthing";
          ports = [8384 22000];
        };
      };
    })
  ];
}
