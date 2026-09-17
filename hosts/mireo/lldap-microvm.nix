# LDAP directory for the homelab (microVM on br0, lldap).
# Identity DATA source (users/groups for Pocket ID OIDC + future RADIUS),
# not an auth platform. Base DN dc=home,dc=arpa matches home.arpa.
# Admin password via host sops (shared read-only into the guest — same
# pattern as voice passwordFiles, only the path enters the store).
# Users are created once in the LLDAP web UI (schema-safe); the admin
# password stays declarative (force reset OFF, warning silenced on purpose).
# Volume holds sqlite DB + auto-generated JWT secret. lldap runs
# DynamicUser upstream, which fails on a mounted volume (same exit 238
# trap as uptime-kuma) — static system user + forced off, like there.
{lib, ...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "lldap";
      ip = (import ./vm-ips.nix).lldap;
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 3890 17170];
      volumes = [
        {
          image = "lldap-data.img";
          mountPoint = "/var/lib/lldap";
          size = 512;
          user = "lldap";
          group = "lldap";
        }
      ];
      shares = [
        {
          tag = "lldap-secrets";
          source = "/run/secrets/lldap";
          mountPoint = "/run/secrets/lldap";
          readOnly = true;
        }
      ];
      config = {
        users.users.lldap = {
          isSystemUser = true;
          group = "lldap";
        };
        users.groups.lldap = {};
        systemd.services.lldap.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "lldap";
        };
        services.lldap = {
          enable = true;
          silenceForceUserPassResetWarning = true;
          settings = {
            ldap_base_dn = "dc=home,dc=arpa";
            ldap_user_dn = "admin";
            ldap_user_email = "admin@home.arpa";
            ldap_user_pass_file = "/run/secrets/lldap/admin-password";
            force_ldap_user_pass_reset = false;
            http_url = "http://lldap.home.arpa";
          };
        };
      };
    })
  ];
}
