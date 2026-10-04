# Identity microVM: OpenLDAP + Keycloak
# Dedicated IP 10.8.0.29, security boundary for identity services.
{...}: {
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
      # NOTE: no identity-secrets share — /run/secrets/identity doesn't
      # exist on the host yet (no sops secrets), so keycloak-secrets-setup
      # will fail inside the guest until they land (guest-local only, never
      # blocks the host switch). A virtiofs share with a missing source
      # would instead fail QEMU at start and break the whole switch
      # (2026-10-04 incident). Land host sops secrets first, then re-add
      # the share in that commit (and drop "identity" from secretlessVMs
      # in tests/default.nix).
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
