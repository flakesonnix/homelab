# OIDC identity provider for the homelab (microVM on br0, Pocket ID v2).
# Users/groups come from LLDAP via LDAP sync (same base DN dc=home,dc=arpa);
# Pocket ID issues OIDC for apps (first client: Grafana). Passkeys are the
# primary login, LDAP-synced users get access by group.
#
# Secrets:
# - ENCRYPTION_KEY is generated on first boot into the data volume
#   (mkKeyGenService, same pattern as grafana secret.key) — never in the
#   store, stable across reboots. Do NOT rotate while the DB lives.
# - LDAP bind reuses the LLDAP admin password: the host renders it via a
#   sops template into /run/secrets/rendered/pocket-id/ (single file, least
#   privilege — NOT the whole /run/secrets/lldap share), staged to tmpfs
#   below (EOPNOTSUPP-safe, same quirk class as lldap-secrets-setup).
#
# Bootstrap order (one-time, Pocket ID has a UI setup wizard):
# 1. deploy mireo (VM + Caddy vhost http://pocket-id.home.arpa come up)
# 2. open Pocket ID UI, create the first admin, verify LDAP users sync
#    (env LDAP_* below; if users are missing, check the service log)
# 3. Settings → OIDC Clients: create client id `grafana` with callback
#    http://grafana.home.arpa/login/generic_oauth, copy the client secret
#    into sops: sops set hosts/mireo/secrets.yaml '["grafana"]["oidc-client-secret"]' '<secret>'
# 4. redeploy mireo, log into Grafana via "Sign in with Pocket ID".
{
  config,
  pkgs,
  ...
}: let
  inherit (import ../../lib/secret-keys.nix pkgs) mkKeyGenService;
  vmIp = (import ./vm-ips.nix).pocket-id;
  lldapIp = (import ./vm-ips.nix).lldap;
in {
  # LDAP bind reuses the LLDAP admin password (single source, no duplicated
  # secret): rendered into a dedicated dir so the guest share sees exactly
  # one file, not all of /run/secrets/lldap. Default template path is
  # /run/secrets/rendered/pocket-id/ldap-bind-password (shared below).
  sops.templates."pocket-id/ldap-bind-password" = {
    content = config.sops.placeholder."lldap/admin-password";
  };
  imports = [
    (import ./mk-microvm.nix {
      name = "pocket-id";
      ip = vmIp;
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 1411];
      volumes = [
        {
          image = "pocket-id-data.img";
          mountPoint = "/var/lib/pocket-id";
          size = 512;
          user = "pocket-id";
          group = "pocket-id";
        }
      ];
      shares = [
        {
          tag = "pocket-id-secrets";
          source = "/run/secrets/rendered/pocket-id";
          mountPoint = "/run/secrets/pocket-id";
          readOnly = true;
        }
      ];
      config = {
        imports = [
          (mkKeyGenService {
            serviceName = "pocket-id";
            secretFile = "/var/lib/pocket-id/encryption.key";
            user = "pocket-id";
            group = "pocket-id";
            bytes = 32;
            format = "base64";
            # Self-heal stale root-owned keys (same phenomenon as grafana
            # 2026-09-14: service user can't read root-owned key file).
            extraCommands = "chown pocket-id:pocket-id /var/lib/pocket-id/encryption.key";
          })
        ];
        # Stage the host-rendered LDAP bind password into guest tmpfs
        # (direct virtiofs reads fail for some tools; root stages once,
        # pocket-id only ever sees /run/pocket-id).
        systemd.services.pocket-id-secrets-setup = {
          description = "Stage Pocket ID secrets from virtiofs share into tmpfs";
          before = ["pocket-id.service"];
          requiredBy = ["pocket-id.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            mkdir -p /run/pocket-id
            install -D -o pocket-id -g pocket-id -m0400 \
              /run/secrets/pocket-id/ldap-bind-password /run/pocket-id/ldap-bind-password
          '';
        };
        services.pocket-id = {
          enable = true;
          settings = {
            APP_URL = "http://pocket-id.home.arpa";
            TRUST_PROXY = true;
            ANALYTICS_DISABLED = true;
            UI_CONFIG_DISABLED = true;
            # REQUIRED for env-based LDAP (and all app config): without it
            # the database defaults win (ldapEnabled=false) and SyncLdap
            # no-ops — verified live (35µs "success", zero connections to
            # LLDAP). Only locks Application Configuration in the UI;
            # user/group/OIDC-client management stays usable.
            # Default Pocket ID port; kept explicit so Caddy (settings.nix)
            # and Grafana oauth endpoints can't drift apart silently.
            PORT = "1411";
            # LDAP user/group source (LLDAP). Filters are Pocket ID
            # defaults and match LLDAP's schema — set explicitly so a
            # default change upstream stays visible here.
            LDAP_ENABLED = true;
            LDAP_URL = "ldap://${lldapIp}:3890";
            LDAP_BASE = "dc=home,dc=arpa";
            LDAP_BIND_DN = "uid=admin,ou=people,dc=home,dc=arpa";
            LDAP_USER_SEARCH_FILTER = "(objectClass=person)";
            LDAP_GROUP_SEARCH_FILTER = "(objectClass=groupOfNames)";
          };
          credentials = {
            ENCRYPTION_KEY = "/var/lib/pocket-id/encryption.key";
            LDAP_BIND_PASSWORD = "/run/pocket-id/ldap-bind-password";
          };
        };
      };
    })
  ];
}
