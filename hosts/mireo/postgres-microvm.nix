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
      # NOTE: no postgres-secrets share — the per-VM host secrets dir
      # doesn't exist yet (no sops secrets), so postgres-secrets-setup
      # stages nothing inside the guest until they land (guest-local only,
      # never blocks the host switch). A virtiofs share with a missing
      # source would instead fail QEMU at start and break the whole switch
      # (2026-10-04 incident). Land host sops secrets first, then re-add
      # the share in that commit (and drop "postgres" from secretlessVMs
      # in tests/default.nix).
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
