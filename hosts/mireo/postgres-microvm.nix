# PostgreSQL microVM: dedicated database platform
# Security boundary, separate failure domain.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "postgres";
      ip = (import ./vm-ips.nix).postgres;
      mem = 2304; # NB: never exactly 2048 (QEMU hangs, microvm.nix#171)
      vcpu = 4;
      tcpPorts = [22 5432];
      volumes = [
        {
          image = "postgres-data.img";
          mountPoint = "/var/lib/postgresql";
          size = 8192;
          user = "postgres";
          group = "postgres";
        }
      ];
      # DB passwords live in host sops (database/*) and are shared here as
      # /run/secrets/postgres so postgres-secrets-setup stages them
      # unchanged into /run/secrets/database. This VM *is* the database
      # host, so sharing the whole database dir is least surprise.
      shares = [
        {
          tag = "postgres-secrets";
          source = "/run/secrets/database";
          mountPoint = "/run/secrets/postgres";
          readOnly = true;
        }
      ];
      tmpfiles = [
        "d /var/lib/postgresql 0750 postgres postgres - -"
      ];
      config = {
        imports = [(import ../../modules/nixos/postgres.nix)];
        lucy.services.postgres = {
          enable = true;
          port = 5432;
          databases = [
            {
              name = "keycloak";
              owner = "keycloak";
              passwordSecret = "database/keycloak";
            }
            {
              name = "nextcloud";
              owner = "nextcloud";
              passwordSecret = "database/nextcloud";
            }
            {
              name = "immich";
              owner = "immich";
              passwordSecret = "database/immich";
            }
            {
              name = "paperless";
              owner = "paperless";
              passwordSecret = "database/paperless";
            }
            {
              name = "netbox";
              owner = "netbox";
              passwordSecret = "database/netbox";
            }
            {
              name = "hydra";
              owner = "hydra";
              passwordSecret = "database/hydra";
            }
            {
              name = "woodpecker";
              owner = "woodpecker";
              passwordSecret = "database/woodpecker";
            }
            {
              name = "librenms";
              owner = "librenms";
              passwordSecret = "database/librenms";
            }
            {
              name = "matrix";
              owner = "matrix";
              passwordSecret = "database/matrix";
            }
          ];
        };
        systemd.services.postgres-secrets-setup = {
          description = "Stage PostgreSQL secrets from virtiofs share";
          before = ["postgresql.service"];
          serviceConfig.Type = "oneshot";
          serviceConfig.RemainAfterExit = true;
          script = ''
            set -eu
            mkdir -p /run/secrets/database
            find /run/secrets/postgres -type f -print0 | while IFS= read -r -d "" f; do
              install -D -o postgres -g postgres -m0400 "$f" "/run/secrets/database/$(basename "$f")"
            done
          '';
        };
        systemd.services.postgresql = {
          after = ["postgres-secrets-setup.service"];
          requires = ["postgres-secrets-setup.service"];
        };
        networking.firewall.allowedTCPPorts = [22 5432];
        networking.firewall.interfaces = {
          "vm-postgres" = {
            allowedTCPPorts = [5432];
          };
        };
      };
    })
  ];
}
