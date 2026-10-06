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
      shares = [
        {
          tag = "artifacts-secrets";
          source = "/run/secrets/artifacts";
          mountPoint = "/run/secrets/artifacts";
          readOnly = true;
        }
      ];
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
