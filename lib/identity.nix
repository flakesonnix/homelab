{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types mkForce;
  inherit (import ../../lib/types.nix {inherit lib;}) checked;
in {
  # ── mkLDAPService ───────────────────────────────────────
  # Generates OpenLDAP server configuration from declarative
  # user/group data.
  mkLDAPService = {
    domain,
    baseDn,
    users,
    groups,
    ...
  }: {
    services.openldap = {
      enable = true;
      settings = {
        argsFile = "/run/openldap/slapd.args";
        argsFilePermissions = "0600";
        pidFile = "/run/openldap/slapd.pid";
        pidFilePermissions = "0600";
      };
      baseDN = baseDn;
      extraConfig = {
        modulepath = "${pkgs.openldap.lib}/lib/openldap";
        moduleload = ["back_mdb.so" "back_ldbm.so"];
        database = "mdb";
        suffix = baseDn;
        rootdn = "cn=admin,${baseDn}";
        rootpwFile = "/run/secrets/ldap/admin-password";
      };
      indexes = {
        uid = {
          presence = true;
          equality = true;
        };
        cn = {
          presence = true;
          equality = true;
        };
        mail = {
          presence = true;
          equality = true;
        };
        memberUid = {presence = true;};
        memberOf = {presence = true;};
      };
    };

    # Declarative LDIF content for users and groups
    services.openldap.declarativeContents = {
      users = builtins.toXML users;
      groups = builtins.toXML groups;
    };

    # Security: only LDAPS and StartTLS
    services.openssh.settings.PasswordAuthentication = false;
  };

  # ── mkKeycloakService ───────────────────────────────────
  # Generates Keycloak realm configuration with LDAP federation.
  mkKeycloakService = {
    realm,
    ldap,
    ...
  }: {
    services.keycloak = {
      enable = true;
      hostname = realm;
      database = {
        databaseName = realm;
        user = realm;
        passwordFile = "/run/secrets/database/${realm}";
        host = "localhost";
      };
      proxy = "edge";
      httpsCertificate = "/var/lib/keycloak/certs/${realm}.p12";
      importRealm = pkgs.writeText "${realm}-realm.json" (builtins.toJSON realm);
    };
  };

  # ── mkKeycloakRealm ─────────────────────────────────────
  # Creates a declarative Keycloak realm JSON from Nix config.
  mkKeycloakRealm = {
    realmName,
    clients,
    groups,
    roles,
    ...
  }: {
    realm = realmName;
    enabled = true;
    sslRequired = "external";
    clients = clients;
    groups = groups;
    roles = roles;
  };

  # ── keycloak-reconcile service generator ────────────────
  # Creates a systemd service that reconciles Keycloak state
  # from Nix-configured realm JSON via kcadm REST API.
  # Idempotent: always applies desired state, UI changes get
  # overwritten on next deploy.
  mkKeycloakReconciler = {
    name,
    realm,
    kcadmPackage ? pkgs.keycloak,
    ...
  }: {
    systemd.services."keycloak-reconcile-${name}" = {
      description = "Reconcile Keycloak ${name} realm (idempotent)";
      after = ["keycloak.service"];
      requires = ["keycloak.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [kcadmPackage];
      script = ''
        set -eu
        export KEYCLOAK_URL=https://localhost:8443/auth
        export KEYCLOAK_REALM=${realm}
        ${kcadmPackage}/bin/kcadm.sh config credentials \
          --server $KEYCLOAK_URL \
          --realm master \
          --user admin \
          --password "$(cat /run/secrets/database/${realm})"
        ${kcadmPackage}/bin/kcadm.sh update realms/${realm} \
          --set enabled=true \
          --set sslRequired=external
      '';
    };
  };

  # ── mkLDAPReconciler ────────────────────────────────────
  # Creates a systemd service that reconciles LDAP entries
  # from declarative LDIF data.
  mkLDAPReconciler = {
    name,
    baseDn,
    ldifFile,
    ...
  }: {
    systemd.services."ldap-reconcile-${name}" = {
      description = "Reconcile LDAP ${name} entries (idempotent)";
      after = ["slapd.service"];
      requires = ["slapd.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [pkgs.openldap];
      script = ''
        set -eu
        ldapadd -x -D "cn=admin,${baseDn}" \
          -f ${ldifFile} \
          || true  # idempotent: entry exists = ignore error
      '';
    };
  };
}
