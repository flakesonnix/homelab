# Service network definitions: ports, visibility, and dependencies.
# This is the single source of truth for firewall rules and
# reverse proxy configuration.
{lib}: let
  inherit (lib) types mkOption;
in {
  services = {
    ldap = {
      name = "ldap";
      ip = "10.8.0.29";
      ports = [636];
      public = false;
      vpnOnly = false;
      dependencies = [];
      dataDirs = [];
      databases = [];
      sopsSecrets = ["ldap/admin-password"];
    };

    keycloak = {
      name = "keycloak";
      ip = "10.8.0.29";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["ldap" "postgres"];
      dataDirs = [];
      databases = [
        {
          name = "keycloak";
          owner = "keycloak";
          passwordSecret = "database/keycloak";
        }
      ];
      sopsSecrets = ["database/keycloak"];
    };

    postgres = {
      name = "postgres";
      ip = "10.8.0.28";
      ports = [5432];
      public = false;
      vpnOnly = true;
      dependencies = [];
      databases = [];
      sopsSecrets = [];
    };

    nextcloud = {
      name = "nextcloud";
      ip = "10.8.0.14";
      ports = [443];
      public = true;
      vpnOnly = false;
      dependencies = ["postgres" "ldap"];
      dataDirs = [
        {
          path = "/data/nextcloud";
          owner = "nextcloud";
          group = "nextcloud";
        }
      ];
      databases = [
        {
          name = "nextcloud";
          owner = "nextcloud";
          passwordSecret = "database/nextcloud";
        }
      ];
      sopsSecrets = ["database/nextcloud"];
    };

    netbox = {
      name = "netbox";
      ip = "10.8.0.15";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/netbox";
          owner = "netbox";
          group = "netbox";
        }
      ];
      databases = [
        {
          name = "netbox";
          owner = "netbox";
          passwordSecret = "database/netbox";
        }
      ];
      sopsSecrets = ["database/netbox"];
    };

    librenms = {
      name = "librenms";
      ip = "10.8.0.16";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/librenms";
          owner = "librenms";
          group = "librenms";
        }
      ];
      databases = [
        {
          name = "librenms";
          owner = "librenms";
          passwordSecret = "database/librenms";
        }
      ];
      sopsSecrets = ["database/librenms"];
    };

    woodpecker = {
      name = "woodpecker";
      ip = "10.8.0.17";
      ports = [80];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/woodpecker";
          owner = "woodpecker";
          group = "woodpecker";
        }
      ];
      databases = [
        {
          name = "woodpecker";
          owner = "woodpecker";
          passwordSecret = "database/woodpecker";
        }
      ];
      sopsSecrets = ["database/woodpecker" "devops/woodpecker-secret"];
    };

    hydra = {
      name = "hydra";
      ip = "10.8.0.18";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/hydra";
          owner = "hydra";
          group = "hydra";
        }
      ];
      databases = [
        {
          name = "hydra";
          owner = "hydra";
          passwordSecret = "database/hydra";
        }
      ];
      sopsSecrets = ["database/hydra"];
    };

    registry = {
      name = "registry";
      ip = "10.8.0.19";
      ports = [5000];
      public = false;
      vpnOnly = true;
      dependencies = [];
      dataDirs = [
        {
          path = "/data/registry";
          owner = "registry";
          group = "registry";
        }
      ];
      databases = [];
      sopsSecrets = [];
    };

    attic = {
      name = "attic";
      ip = "10.8.0.20";
      ports = [80];
      public = false;
      vpnOnly = true;
      dependencies = [];
      dataDirs = [
        {
          path = "/data/attic";
          owner = "attic";
          group = "attic";
        }
      ];
      databases = [];
      sopsSecrets = [];
    };

    immich = {
      name = "immich";
      ip = "10.8.0.21";
      ports = [443];
      public = true;
      vpnOnly = false;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/immich";
          owner = "immich";
          group = "immich";
        }
      ];
      databases = [
        {
          name = "immich";
          owner = "immich";
          passwordSecret = "database/immich";
        }
      ];
      sopsSecrets = ["database/immich"];
    };

    paperless = {
      name = "paperless";
      ip = "10.8.0.22";
      ports = [80];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/paperless";
          owner = "paperless";
          group = "paperless";
        }
      ];
      databases = [
        {
          name = "paperless";
          owner = "paperless";
          passwordSecret = "database/paperless";
        }
      ];
      sopsSecrets = ["database/paperless"];
    };

    matrix = {
      name = "matrix";
      ip = "10.8.0.23";
      ports = [443 8448];
      public = true;
      vpnOnly = false;
      dependencies = ["postgres"];
      dataDirs = [
        {
          path = "/data/matrix";
          owner = "matrix";
          group = "matrix";
        }
      ];
      databases = [
        {
          name = "matrix";
          owner = "matrix";
          passwordSecret = "database/matrix";
        }
      ];
      sopsSecrets = ["matrix/registration_shared_secret"];
    };

    ntfy = {
      name = "ntfy";
      ip = "10.8.0.24";
      ports = [443];
      public = true;
      vpnOnly = false;
      dependencies = [];
      dataDirs = [
        {
          path = "/data/ntfy";
          owner = "ntfy";
          group = "ntfy";
        }
      ];
      databases = [];
      sopsSecrets = ["ntfy/admin-token"];
    };

    rustdesk = {
      name = "rustdesk";
      ip = "10.8.0.25";
      ports = [21115 21116 21118 21119 21121 21122 21123 21124];
      public = false;
      vpnOnly = true;
      dependencies = [];
      dataDirs = [
        {
          path = "/data/rustdesk";
          owner = "rustdesk";
          group = "rustdesk";
        }
      ];
      databases = [];
      sopsSecrets = [];
    };

    syncthing = {
      name = "syncthing";
      ip = "10.8.0.26";
      ports = [8384 22000];
      public = false;
      vpnOnly = true;
      dependencies = [];
      dataDirs = [
        {
          path = "/data/syncthing";
          owner = "syncthing";
          group = "syncthing";
        }
      ];
      databases = [];
      sopsSecrets = [];
    };
  };
}
