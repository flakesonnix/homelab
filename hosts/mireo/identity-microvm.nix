# Identity microVM: OpenLDAP + Keycloak
# Dedicated IP 10.8.0.29, security boundary for identity services.
{config, ...}: {
  # Keycloak DB password reuses the host database/keycloak secret (single
  # source, no duplicated secret): rendered into a dedicated dir so the
  # guest share sees exactly one file (same pattern as pocket-id).
  sops.templates."identity/database/keycloak" = {
    content = config.sops.placeholder."database/keycloak";
  };
  imports = [
    (import ./mk-microvm.nix {
      name = "identity";
      ip = (import ./vm-ips.nix).identity;
      mem = 1024;
      vcpu = 2;
      tcpPorts = [22 443 636];
      volumes = [
        {
          image = "ldap-data.img";
          mountPoint = "/var/lib/openldap";
          size = 2048;
          user = "openldap";
          group = "openldap";
        }
        {
          image = "keycloak-data.img";
          mountPoint = "/var/lib/keycloak";
          size = 2048;
          user = "keycloak";
          group = "keycloak";
        }
      ];
      # Rendered template above lands at
      # /run/secrets/rendered/identity/database/keycloak on the host.
      shares = [
        {
          tag = "identity-secrets";
          source = "/run/secrets/rendered/identity";
          mountPoint = "/run/secrets/identity/database";
          readOnly = true;
        }
      ];
      tmpfiles = [
        "d /var/lib/openldap 0750 openldap openldap - -"
        "d /var/lib/keycloak 0750 keycloak keycloak - -"
      ];
      config = {
        imports = [
          (import ../../modules/nixos/identity-openldap.nix)
          (import ../../modules/nixos/identity-keycloak.nix)
        ];
        lucy.services.identity = {
          enable = true;
          domain = "home.arpa";
          baseDN = "dc=home,dc=arpa";
        };
        systemd.services.keycloak-secrets-setup = {
          description = "Stage Keycloak secrets from virtiofs share";
          before = ["keycloak.service"];
          serviceConfig.Type = "oneshot";
          serviceConfig.RemainAfterExit = true;
          script = ''
            set -eu
            mkdir -p /run/secrets/database
            install -D -o keycloak -g keycloak -m0400 /run/secrets/identity/database/keycloak /run/secrets/database/keycloak
          '';
        };
        networking.firewall.allowedTCPPorts = [22 443 636];
      };
    })
  ];
}
