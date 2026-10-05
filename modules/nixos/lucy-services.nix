{
  lib,
  pkgs,
  ...
}: {
  options.lucy.services = {
    # ── Platform services ────────────────────────────────
    postgres = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 5432;
          };
          databases = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule ({options, ...}: {
              options = {
                name = lib.mkOption {type = lib.types.nonEmptyStr;};
                owner = lib.mkOption {type = lib.types.nonEmptyStr;};
                passwordSecret = lib.mkOption {type = lib.types.nonEmptyStr;};
              };
            }));
            default = [];
          };
        };
      });
    };

    identity = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          domain = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "home.arpa";
          };
          baseDN = lib.mkOption {
            type = lib.types.str;
            default = "dc=home,dc=arpa";
          };
          ldapAdminPasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "ldap/admin-password";
          };
          keycloakAdminPasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/keycloak";
          };
        };
      });
    };

    dns = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          domain = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "home.arpa";
          };
          upstream = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = ["1.1.1.1"];
          };
          blocklists = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          forwardDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      });
    };

    reverseProxy = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          domain = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "home.arpa";
          };
          publicDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          internalDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          tlsEmail = lib.mkOption {
            type = lib.types.str;
            default = null;
          };
        };
      });
    };

    # ── Application services ────────────────────────────
    nextcloud = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          host = lib.mkOption {type = lib.types.nonEmptyStr;};
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/nextcloud";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "nextcloud";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "nextcloud";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/nextcloud";
          };
          adminPasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/nextcloud";
          };
        };
      });
    };

    syncthing = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/syncthing";
          };
          ports = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [8384 22000];
          };
        };
      });
    };

    immich = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/immich";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "immich";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "immich";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/immich";
          };
        };
      });
    };

    paperless = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/paperless";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "paperless";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "paperless";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/paperless";
          };
        };
      });
    };

    woodpecker = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/woodpecker";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "woodpecker";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "woodpecker";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/woodpecker";
          };
          secretSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "devops/woodpecker-secret";
          };
        };
      });
    };

    hydra = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/hydra";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "hydra";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "hydra";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/hydra";
          };
        };
      });
    };

    registry = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/registry";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 5000;
          };
        };
      });
    };

    attic = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/attic";
          };
        };
      });
    };

    netbox = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/netbox";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "netbox";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "netbox";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/netbox";
          };
        };
      });
    };

    librenms = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/librenms";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "librenms";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "librenms";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/librenms";
          };
        };
      });
    };

    matrix = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/matrix";
          };
          databaseName = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "matrix";
          };
          databaseUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "matrix";
          };
          databasePasswordSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "database/matrix";
          };
          registrationSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "matrix/registration_shared_secret";
          };
        };
      });
    };

    ntfy = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/ntfy";
          };
          adminTokenSecret = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "ntfy/admin-token";
          };
        };
      });
    };

    rustdesk = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/rustdesk";
          };
        };
      });
    };

    mopidy = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          musicDirectory = lib.mkOption {
            type = lib.types.path;
            default = "/data/Music";
          };
          alsaDevice = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "hw:CARD=CODEC,DEV=0";
          };
          jellyfinHost = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "10.8.0.10:8096";
          };
          jellyfinUser = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "mopidy";
          };
        };
      });
    };

    minecraft = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          user = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "lucy";
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/home/lucy/mcserver";
          };
          jar = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "server.jar";
          };
          memory = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "6G";
          };
          javaPackage = lib.mkOption {
            type = lib.types.package;
            # Paper 26.x needs Java 25 (class file 69.0); Temurin 21 dies
            # with UnsupportedClassVersionError (seen 2026-10-03, exit 1).
            default = pkgs.temurin-jre-bin-25;
          };
        };
      });
    };

    osm = lib.mkOption {
      type = lib.types.submodule ({config, ...}: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          dataDir = lib.mkOption {
            type = lib.types.path;
            default = "/data/osm";
          };
          region = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "germany";
          };
          postgresDatabase = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "osm";
          };
        };
      });
    };
  };
}
