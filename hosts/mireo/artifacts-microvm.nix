# Artifacts microVM: Attic binary cache + OCI Registry
# Binary cache and container registry.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "artifacts";
      ip = (import ./vm-ips.nix).attic;
      mem = 1024;
      vcpu = 2;
      tcpPorts = [22 80 5000];
      volumes = [
        {
          image = "attic-data.img";
          mountPoint = "/data/attic";
          size = 4096;
          user = "attic";
          group = "attic";
        }
        {
          image = "registry-data.img";
          mountPoint = "/data/registry";
          size = 4096;
          user = "registry";
          group = "registry";
        }
      ];
      # NOTE: no artifacts-secrets share — the per-VM host secrets dir
      # doesn't exist yet (no sops secrets). A virtiofs share with a
      # missing source fails QEMU at start and breaks the whole switch
      # (2026-10-04 incident). Land host sops secrets first, then re-add
      # the share in that commit (and drop "artifacts" from secretlessVMs
      # in tests/default.nix).
      tmpfiles = [
        "d /data/attic 0750 attic attic - -"
        "d /data/registry 0750 registry registry - -"
      ];
      config = {
        imports = [
          (import ../../modules/nixos/attic.nix)
          (import ../../modules/nixos/registry.nix)
        ];
        lucy.services.attic = {
          enable = true;
          dataDir = "/data/attic";
        };
        lucy.services.registry = {
          enable = true;
          dataDir = "/data/registry";
          port = 5000;
        };
        # Add pci-setup script to satisfy ConditionPathExists in microvm-pci-devices@.service
        systemd.services."pci-setup-artifacts" = {
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/true";
          };
        };
      };
    })
  ];
}
