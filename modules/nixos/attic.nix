{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.attic;
in {
  config = lib.mkIf cfg.enable {
    services.atticd = {
      enable = true;
      # RS256 token secret, staged from host sops via virtiofs share.
      # Host must provide `artifacts/attic-env` with:
      #   ATTIC_SERVER_TOKEN_RS256_SECRET="<base64 RSA key>"
      environmentFile = "/run/secrets/artifacts/attic-env";
    };
    networking.firewall.allowedTCPPorts = [80];
    networking.firewall.interfaces."vm-artifacts" = {
      allowedTCPPorts = [80];
    };
    systemd.services.atticd = {
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
    };
    systemd.services.attic-secrets-setup = {
      description = "Stage Attic secrets from virtiofs share";
      before = ["atticd.service"];
      requiredBy = ["atticd.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /run/secrets/database /run/secrets/artifacts
        find /run/secrets/artifacts -type f -print0 | while IFS= read -r -d "" f; do
          install -D -o attic -g attic -m0400 "$f" "/run/secrets/artifacts/$(basename "$f")"
        done
      '';
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 attic attic - -"
    ];
  };
}
