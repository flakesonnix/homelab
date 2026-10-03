# Declarative identity data model for OpenLDAP.
# Users and groups are the source of truth for the directory.
# Passwords live in SOPS, never here.
{lib}: let
  inherit (lib) types mkOption;
in {
  # Base DN for the directory.
  baseDN = "dc=home,dc=arpa";
  domain = "home.arpa";

  # Users are defined by their LDAP-visible attributes.
  # Password files are staged from sops at runtime.
  users = {
    lucy = {
      uid = "lucy";
      cn = "Lucy";
      sn = "Doe";
      displayName = "Lucy";
      givenName = "Lucy";
      mail = "lucy@home.arpa";
      userPasswordFile = "/run/secrets/ldap/users/lucy";
    };
  };

  # Groups define access and role mappings.
  groups = {
    admins = {
      cn = "admins";
      gidNumber = 1000;
      description = "Administrative group";
      members = ["lucy"];
    };
    users = {
      cn = "users";
      gidNumber = 1001;
      description = "Default user group";
      members = ["lucy"];
    };
    services = {
      cn = "services";
      gidNumber = 1002;
      description = "Service accounts";
      members = [];
    };
  };

  # Service accounts (system users in the directory).
  serviceAccounts = {
    nextcloud = {
      uid = "nextcloud";
      cn = "nextcloud";
      mail = "nextcloud@home.arpa";
      userPasswordFile = "/run/secrets/ldap/users/nextcloud";
    };
    immich = {
      uid = "immich";
      cn = "immich";
      mail = "immich@home.arpa";
      userPasswordFile = "/run/secrets/ldap/users/immich";
    };
  };
}
