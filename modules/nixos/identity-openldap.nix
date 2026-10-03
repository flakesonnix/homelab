{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.identity;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [636];
    networking.firewall.interfaces."vm-identity" = {
      allowedTCPPorts = [636];
    };
    systemd.services.openldap = {
      description = "OpenLDAP directory server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.keycloak = {
      description = "Keycloak SSO identity provider";
      wantedBy = ["multi-user.target"];
      after = ["openldap.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/openldap 0750 openldap openldap - -"
      "d /var/lib/keycloak 0750 keycloak keycloak - -"
    ];
  };
}
