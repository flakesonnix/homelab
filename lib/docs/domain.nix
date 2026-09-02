# Domain model — typed entities for the homelab.
# These are independent of renderers; renderers only see the AST.
{lib}: let
  inherit (lib) types mkOption;
in rec {
  # Generic entity
  mkEntity = {
    type, # string: host, service, module, microvm, package, role, bundle, preset, network, deployment
    id, # unique id, e.g. "mireo", "dnsmasq"
    title,
    description ? "",
    tags ? [],
    metadata ? {},
    relations ? {}, # { runs = ["service:dnsmasq"]; uses = ["module:base"]; contains = ["microvm:grafana"] }
  }: {
    inherit type id title description tags metadata relations;
    _type = "entity";
  };

  # Host
  mkHost = {
    id,
    title,
    description ? "",
    hardware ? {},
    network ? {},
    services ? [], # list of service ids
    microvms ? [], # list of microvm ids
    roles ? [],
    modules ? [],
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "host";
      inherit id title description tags metadata;
      relations = {
        runs = map (s: "service:${s}") services;
        contains = map (v: "microvm:${v}") microvms;
        uses = map (m: "module:${m}") modules;
        belongs = map (r: "role:${r}") roles;
      };
    }
    // {
      inherit hardware network services microvms roles modules;
    };

  # Service
  mkService = {
    id,
    title,
    description ? "",
    port ? null,
    protocol ? null,
    host ? null,
    microvm ? null,
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "service";
      inherit id title description tags metadata;
      relations = lib.optionalAttrs (host != null) {runsOn = ["host:${host}"];} // lib.optionalAttrs (microvm != null) {runsOn = ["microvm:${microvm}"];};
    }
    // {
      inherit port protocol host microvm;
    };

  # Module
  mkModule = {
    id,
    title,
    description ? "",
    options ? {},
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "module";
      inherit id title description tags metadata;
    }
    // {
      inherit options;
    };

  # MicroVM
  mkMicroVM = {
    id,
    title,
    description ? "",
    host ? "mireo",
    ip ? null,
    mem ? null,
    vcpu ? null,
    services ? [],
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "microvm";
      inherit id title description tags metadata;
      relations = {
        runsOn = ["host:${host}"];
        runs = map (s: "service:${s}") services;
      };
    }
    // {
      inherit host ip mem vcpu services;
    };

  # Package
  mkPackage = {
    id,
    title,
    description ? "",
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "package";
      inherit id title description tags metadata;
    };

  # Role
  mkRole = {
    id,
    title,
    description ? "",
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "role";
      inherit id title description tags metadata;
    };

  # Bundle
  mkBundle = {
    id,
    title,
    description ? "",
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "bundle";
      inherit id title description tags metadata;
    };

  # Preset
  mkPreset = {
    id,
    title,
    description ? "",
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "preset";
      inherit id title description tags metadata;
    };

  # Network
  mkNetwork = {
    id,
    title,
    description ? "",
    cidr ? null,
    gateway ? null,
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "network";
      inherit id title description tags metadata;
    }
    // {
      inherit cidr gateway;
    };

  # Deployment
  mkDeployment = {
    id,
    title,
    description ? "",
    host ? null,
    tags ? [],
    metadata ? {},
  }:
    mkEntity {
      type = "deployment";
      inherit id title description tags metadata;
      relations = lib.optionalAttrs (host != null) {deploys = ["host:${host}"];};
    }
    // {
      inherit host;
    };
}
