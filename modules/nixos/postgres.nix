{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.postgres;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [cfg.port];
    networking.firewall.interfaces."vm-postgres" = {
      allowedTCPPorts = [cfg.port];
    };
    systemd.services.postgresql = {
      description = "PostgreSQL database server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.postgres-secrets-setup = {
      description = "Stage PostgreSQL secrets from virtiofs share";
      before = ["postgresql.service"];
      requiredBy = ["postgresql.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /run/secrets/database
        find /run/secrets/postgres -type f -print0 | while IFS= read -r -d "" f; do
          install -D -o postgres -g postgres -m0400 "$f" "/run/secrets/database/$(basename "$f")"
        done
      '';
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/postgresql 0750 postgres postgres - -"
    ];
  };
}
