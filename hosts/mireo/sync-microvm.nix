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
      # NOTE: no sync-secrets share — the per-VM host secrets dir doesn't
      # exist yet (no sops secrets). A virtiofs share with a missing
      # source fails QEMU at start and breaks the whole switch (2026-10-04
      # incident). Land host sops secrets first, then re-add the share in
      # that commit (and drop "sync" from secretlessVMs in
      # tests/default.nix).
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
