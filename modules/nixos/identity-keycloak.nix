{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.identity;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.interfaces."vm-identity" = {
      allowedTCPPorts = [443];
    };
    systemd.services.keycloak = {
      description = "Keycloak SSO identity provider";
      wantedBy = ["multi-user.target"];
      after = ["openldap.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.keycloak-secrets-setup = {
      description = "Stage Keycloak secrets from virtiofs share";
      before = ["keycloak.service"];
      requiredBy = ["keycloak.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /run/secrets/database
        install -D -o keycloak -g keycloak -m0400 \
          /run/secrets/identity/database/keycloak /run/secrets/database/keycloak
      '';
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/keycloak 0750 keycloak keycloak - -"
    ];
  };
}
