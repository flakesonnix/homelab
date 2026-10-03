{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (import ../../lib/types.nix {inherit lib;}) checked serviceDefSpec;
in {
  # Central service definitions for the homelab.
  # Each service gets a typed spec with IP, ports, dependencies,
  # data directories, databases, and SOPS secrets.
  #
  # This drives: firewall rules, DNS records, reverse proxy,
  # monitoring, and microVM definitions.
  services = {
    # Platform services
    postgres = {
      name = "postgres";
      ip = "10.8.0.28";
      ports = [5432];
      public = false;
      vpnOnly = true;
      dependencies = [];
      databases = [
        {
          name = "keycloak";
          owner = "keycloak";
          passwordSecret = "database/keycloak";
        }
        {
          name = "nextcloud";
          owner = "nextcloud";
          passwordSecret = "database/nextcloud";
        }
        {
          name = "immich";
          owner = "immich";
          passwordSecret = "database/immich";
        }
        {
          name = "paperless";
          owner = "paperless";
          passwordSecret = "database/paperless";
        }
        {
          name = "netbox";
          owner = "netbox";
          passwordSecret = "database/netbox";
        }
        {
          name = "hydra";
          owner = "hydra";
          passwordSecret = "database/hydra";
        }
        {
          name = "woodpecker";
          owner = "woodpecker";
          passwordSecret = "database/woodpecker";
        }
        {
          name = "librenms";
          owner = "librenms";
          passwordSecret = "database/librenms";
        }
        {
          name = "matrix";
          owner = "matrix";
          passwordSecret = "database/matrix";
        }
      ];
      sopsSecrets = [];
    };

    # Identity services
    ldap = {
      name = "ldap";
      ip = "10.8.0.29";
      ports = [636];
      public = false;
      vpnOnly = false;
      dependencies = [];
      sopsSecrets = ["ldap/admin-password" "ldap/replication-password"];
    };

    keycloak = {
      name = "keycloak";
      ip = "10.8.0.29";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["ldap" "postgres"];
      sopsSecrets = ["database/keycloak"];
    };

    # Network services
    dns = {
      name = "dns";
      ip = "10.8.0.30";
      ports = [53];
      public = false;
      vpnOnly = false;
      dependencies = [];
      sopsSecrets = [];
    };

    reverse-proxy = {
      name = "reverse-proxy";
      ip = "10.8.0.1";
      ports = [80 443];
      public = true;
      vpnOnly = false;
      dependencies = ["dns"];
      sopsSecrets = [];
    };

    # DevOps services
    woodpecker = {
      name = "woodpecker";
      ip = "10.8.0.17";
      ports = [80];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres" "keycloak"];
      sopsSecrets = ["database/woodpecker" "devops/woodpecker-secret"];
    };

    hydra = {
      name = "hydra";
      ip = "10.8.0.18";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      sopsSecrets = ["database/hydra"];
    };

    attic = {
      name = "attic";
      ip = "10.8.0.20";
      ports = [80];
      public = false;
      vpnOnly = true;
      dependencies = [];
      sopsSecrets = [];
    };

    registry = {
      name = "registry";
      ip = "10.8.0.19";
      ports = [5000];
      public = false;
      vpnOnly = true;
      dependencies = [];
      sopsSecrets = [];
    };

    # Management services
    netbox = {
      name = "netbox";
      ip = "10.8.0.15";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      sopsSecrets = ["database/netbox"];
    };

    librenms = {
      name = "librenms";
      ip = "10.8.0.16";
      ports = [443];
      public = false;
      vpnOnly = true;
      dependencies = ["postgres"];
      sopsSecrets = ["database/librenms"];
    };

    # Application services
    nextcloud = {
      name = "nextcloud";
      ip = "10.8.0.14";
      ports = [443];
      public = true;
      vpnOnly = false;
      dependencies = ["postgres" "ldap" "keycloak"];
      dataDirs = [
        {
          path = "/data/nextcloud";
          owner = "nextcloud";
          group = "nextcloud";
        }
      ];
      sopsSecrets = ["database/nextcloud"];
    };

    immich = {
      name = "immich";
      ip = "10.8.0.21";
      ports = [443];
      public = true;
      vpnOnly = false;
      dependencies = ["postgres" "keycloak"];
      dataDirs = [
        {
          path = "/data/immich";
          owner = "immich";
          group = "immich";
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
      dependencies = ["postgres" "keycloak"];
      dataDirs = [
        {
          path = "/data/paperless";
          owner = "paperless";
          group = "paperless";
        }
      ];
      sopsSecrets = ["database/paperless"];
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
      sopsSecrets = [];
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
      sopsSecrets = ["matrix/registration_shared_secret" "matrix/macaroon_secret" "matrix/form_secret"];
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
      sopsSecrets = [];
    };
  };

  # Helper to get all service names.
  serviceNames = builtins.attrNames services;

  # Helper to get a service by name.
  getService = name: services.${name};

  # Generate firewall port list from all services.
  publicPorts = lib.concatLists (lib.mapAttrsToList (_name: svc: lib.optionals svc.public svc.ports) services);
  publicTCPPorts = lib.concatLists (lib.mapAttrsToList (_name: svc: lib.optionals svc.public svc.ports) services);
}
