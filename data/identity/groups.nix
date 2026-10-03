# Group definitions for the homelab LDAP directory.
# These groups map to Keycloak roles for SSO.
{lib}: let
  inherit (lib) types mkOption;
in {
  # Keycloak role mappings: each LDAP group maps to a Keycloak role.
  roleMappings = {
    admins = "admin";
    users = "user";
    services = "service";
  };

  # LDAP group entries for the directory.
  entries = {
    admins = {
      cn = "admins";
      gidNumber = 1000;
      description = "Administrative access";
    };
    users = {
      cn = "users";
      gidNumber = 1001;
      description = "Standard users";
    };
    services = {
      cn = "services";
      gidNumber = 1002;
      description = "Service accounts";
    };
  };
}
