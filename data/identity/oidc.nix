# OIDC client definitions for the homelab.
# Each service that uses Keycloak OIDC is defined here.
# Secrets (clientSecret) live in SOPS.
{lib}: let
  inherit (lib) types mkOption;
in {
  # Keycloak issuer URL.
  issuer = "https://keycloak.home.arpa";

  # OIDC clients registered in Keycloak.
  clients = {
    nextcloud = {
      name = "nextcloud";
      clientId = "nextcloud";
      clientSecretSecret = "database/keycloak";
      redirectUri = "https://nextcloud.home.arpa/login";
      scopes = ["openid" "email" "profile" "groups"];
    };
    grafana = {
      name = "grafana";
      clientId = "grafana";
      clientSecretSecret = "grafana/oidc-client-secret";
      redirectUri = "http://grafana.home.arpa/login/generic_oauth";
      scopes = ["openid" "email" "profile" "groups"];
    };
    woodpecker = {
      name = "woodpecker";
      clientId = "woodpecker";
      clientSecretSecret = "devops/woodpecker-secret";
      redirectUri = "https://woodpecker.home.arpa/login";
      scopes = ["openid" "email" "profile" "groups"];
    };
    netbox = {
      name = "netbox";
      clientId = "netbox";
      clientSecretSecret = "devops/netbox-secret";
      redirectUri = "https://netbox.home.arpa/login";
      scopes = ["openid" "email" "profile"];
    };
  };
}
