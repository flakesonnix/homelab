# DevOps microVM: Woodpecker + Hydra
# CI/CD build services.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "devops";
      ip = (import ./vm-ips.nix).woodpecker;
      mem = 2048;
      vcpu = 4;
      tcpPorts = [22 80];
      volumes = [
        {
          image = "woodpecker-data.img";
          mountPoint = "/data/woodpecker";
          size = 1024;
          user = "woodpecker";
          group = "woodpecker";
        }
        {
          image = "hydra-data.img";
          mountPoint = "/data/hydra";
          size = 2048;
          user = "hydra";
          group = "hydra";
        }
      ];
      shares = [
        {
          tag = "devops-secrets";
          source = "/run/secrets/devops";
          mountPoint = "/run/secrets/devops";
          readOnly = true;
        }
      ];
      tmpfiles = [
        "d /data/woodpecker 0750 woodpecker woodpecker - -"
        "d /data/hydra 0750 hydra hydra - -"
      ];
      config = {
        imports = [
          (import ../../modules/nixos/woodpecker.nix)
          (import ../../modules/nixos/hydra.nix)
        ];
        lucy.services.woodpecker = {
          enable = true;
          dataDir = "/data/woodpecker";
          databaseName = "woodpecker";
          databaseUser = "woodpecker";
          databasePasswordSecret = "database/woodpecker";
          secretSecret = "devops/woodpecker-secret";
        };
        lucy.services.hydra = {
          enable = true;
          dataDir = "/data/hydra";
          databaseName = "hydra";
          databaseUser = "hydra";
          databasePasswordSecret = "database/hydra";
        };
      };
    })
  ];
}
