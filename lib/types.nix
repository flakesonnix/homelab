# Own data types and helpers shared across the configuration (data model,
# VMs, services).
{lib}: let
  inherit (lib) mkOption types;
in rec {
  # IPv4 address, e.g. "10.8.0.5".
  ipv4 = types.strMatching "^([0-9]{1,3}\\.){3}[0-9]{1,3}$";

  # Evaluates a raw attrset through a submodule option type: defaults are
  # applied, unknown or ill-typed fields abort evaluation.
  checked = specType: spec:
    (lib.evalModules {
      modules = [
        {
          options.spec = mkOption {type = specType;};
          config.spec = spec;
        }
      ];
    }).config.spec;

  # A tagged package registry entry (data/packages/*.nix).
  packageEntry = types.submodule {
    options = {
      description = mkOption {type = types.str;};
      targets = mkOption {type = types.listOf (types.enum ["user" "system" "home"]);};
      packages.user = mkOption {
        type = types.listOf types.package;
        default = [];
      };
      packages.system = mkOption {
        type = types.listOf types.package;
        default = [];
      };
      packages.home = mkOption {
        type = types.listOf types.package;
        default = [];
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
  };
  packageRegistryType = types.attrsOf packageEntry;

  # ── Homelab service types ────────────────────────────────

  # A database specification for mkPostgresDatabase.
  dbSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      owner = mkOption {type = types.nonEmptyStr;};
      passwordSecret = mkOption {type = types.nonEmptyStr;};
      port = mkOption {
        type = types.port;
        default = 5432;
      };
      ensureTables = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      replication = mkOption {
        type = types.bool;
        default = false;
      };
      backup = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };

  # A PostgreSQL database result (after mkPostgresDatabase expansion).
  dbResult = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      owner = mkOption {type = types.nonEmptyStr;};
      passwordSecret = mkOption {type = types.nonEmptyStr;};
      port = mkOption {type = types.port;};
      ensureTables = mkOption {type = types.listOf types.str;};
      backup = mkOption {type = types.bool;};
    };
  };

  # A reverse-proxy target specification for mkReverseProxy.
  reverseProxySpec = types.submodule {
    options = {
      host = mkOption {type = types.nonEmptyStr;};
      upstream = mkOption {type = types.str;};
      port = mkOption {
        type = types.port;
        default = 443;
      };
      tls = mkOption {
        type = types.bool;
        default = true;
      };
      public = mkOption {
        type = types.bool;
        default = false;
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };
    };
  };

  # A reconciler specification for mkReconciler.
  reconcilerSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      description = mkOption {
        type = types.str;
        default = "";
      };
      after = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      script = mkOption {type = types.lines;};
      requires = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      wantedBy = mkOption {
        type = types.listOf types.str;
        default = ["multi-user.target"];
      };
      serviceConfig = mkOption {
        type = types.attrs;
        default = {};
      };
      environment = mkOption {
        type = types.attrs;
        default = {};
      };
      path = mkOption {
        type = types.listOf types.package;
        default = [];
      };
    };
  };

  # An OIDC client specification for mkOIDCClient.
  oidcClientSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      clientId = mkOption {type = types.nonEmptyStr;};
      clientSecretSecret = mkOption {type = types.nonEmptyStr;};
      redirectUri = mkOption {type = types.str;};
      scopes = mkOption {
        type = types.listOf types.str;
        default = ["openid" "email" "profile"];
      };
      issuer = mkOption {
        type = types.str;
        default = "https://keycloak.home.arpa";
      };
    };
  };

  # A firewall rule specification for mkFirewallRule.
  firewallRuleSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      ports = mkOption {type = types.listOf types.port;};
      protocol = mkOption {
        type = types.enum ["tcp" "udp" "both"];
        default = "tcp";
      };
      public = mkOption {
        type = types.bool;
        default = false;
      };
      interface = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  # A storage directory specification for mkDataDirectory.
  dataDirectorySpec = types.submodule {
    options = {
      path = mkOption {type = types.path;};
      owner = mkOption {type = types.nonEmptyStr;};
      group = mkOption {type = types.nonEmptyStr;};
      mode = mkOption {
        type = types.strMatching "^[0-7]{3,4}$";
        default = "0750";
      };
      quota = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
      };
    };
  };

  # A service definition for the declarative service model.
  serviceDefSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      ip = mkOption {type = ipv4;};
      ports = mkOption {
        type = types.listOf types.port;
        default = [];
      };
      public = mkOption {
        type = types.bool;
        default = false;
      };
      vpnOnly = mkOption {
        type = types.bool;
        default = false;
      };
      dependencies = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      dataDirs = mkOption {
        type = types.listOf dataDirectorySpec;
        default = [];
      };
      databases = mkOption {
        type = types.listOf dbSpec;
        default = [];
      };
      sopsSecrets = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      reverseProxy = mkOption {
        type = types.nullOr reverseProxySpec;
        default = null;
      };
    };
  };

  # A network site specification.
  siteSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      vlan = mkOption {type = types.ints.positive;};
      gateway = mkOption {type = ipv4;};
      prefix = mkOption {
        type = types.ints.positive;
        default = 24;
      };
      dns = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };

  # A network device specification for NetBox/LibreNMS.
  deviceSpec = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      site = mkOption {type = types.nonEmptyStr;};
      role = mkOption {type = types.nonEmptyStr;};
      manufacturer = mkOption {type = types.nonEmptyStr;};
      model = mkOption {type = types.nonEmptyStr;};
      interfaces = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      addresses = mkOption {
        type = types.listOf ipv4;
        default = [];
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      snmpCommunity = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
}
