# homectl artifact generator — pure Nix, no runtime logic.
#
# Produces the two JSON artifacts (manifest.json, ui.json) that drive homectl.
# Everything here is derived from the flake: nixosConfigurations, the data/
# model and the homectl module options. Go and React only read the output.
# Pattern mirrors lib/topology.nix: pure Nix evaluated at build time.
{
  lib,
  pkgs,
  configurations,
  deployNodes ? {},
}: let
  inherit
    (builtins)
    attrNames
    attrValues
    mapAttrs
    listToAttrs
    toJSON
    tryEval
    isList
    head
    split
    filter
    elem
    readDir
    ;
  inherit (lib) concatLists concatMap unique optionalAttrs hasSuffix removeSuffix;

  # ----------------------------------------------------------------------
  # data model (read-only, single source of truth)
  # ----------------------------------------------------------------------

  nixFiles = dir:
    map (f: removeSuffix ".nix" f) (filter (f: hasSuffix ".nix" f) (attrNames (readDir dir)));

  roles = let
    dir = ../data/roles;
  in
    listToAttrs (map (n: {
      name = n;
      value = import (dir + "/${n}.nix");
    }) (nixFiles dir));

  bundles = let
    dir = ../data/bundles;
  in
    listToAttrs (map (n: {
      name = n;
      value = import (dir + "/${n}.nix");
    }) (nixFiles dir));

  presets = let
    dir = ../data/presets;
  in
    listToAttrs (map (n: {
      name = n;
      value = import (dir + "/${n}.nix");
    }) (nixFiles dir));

  registryNames = registry:
    listToAttrs (map (tag: {
      name = tag;
      value = builtins.attrNames (lib.filterAttrs (n: e: elem tag e.tags) registry);
    }) (unique (concatLists (map (e: e.tags) (attrValues registry)))));

  # ----------------------------------------------------------------------
  # host extraction
  # ----------------------------------------------------------------------

  hostRolesFile = host: ../data/hosts/${host}/roles.nix;

  hostRoles = host: let
    dir = tryEval (readDir (../data/hosts + "/${host}"));
  in
    if !dir.success || !(builtins.hasAttr "roles.nix" dir.value)
    then []
    else import (hostRolesFile host);

  roleOf = name: roles.${name} or (throw "homectl manifest: unknown role ${name}");

  hostView = name: cfg: let
    roleNames = hostRoles name;
    roleAttrs = map roleOf roleNames;
    hostPayloads = map (r: r.host or {}) roleAttrs;
    homePayloads = map (r: r.home or {}) roleAttrs;
    presetNames = unique (concatMap (p: p.presets or []) hostPayloads);
    presetAttrs = map (p: presets.${p} or (throw "homectl manifest: unknown preset ${p}")) presetNames;
    moduleFlags = lib.foldl' (a: b: a // (b.moduleFlags or {})) {} (hostPayloads ++ presetAttrs);
    packageTags = unique (concatMap (p: p.packageTags or []) hostPayloads);
    bundlesOf = unique (concatLists (map (p: p.bundles or []) homePayloads));
  in {
    hostname = cfg.config.networking.hostName;
    roles = roleNames;
    bundles = bundlesOf;
    presets = presetNames;
    inherit moduleFlags;
    inherit packageTags;
    packages = registryNames (import ../data/packages/system.nix {inherit pkgs;});
  };

  # ----------------------------------------------------------------------
  # microvm extraction
  # ----------------------------------------------------------------------

  addrOf = a:
    if isList a
    then addrOf (head a)
    else if builtins.isString a
    then head (split "/" a)
    else if builtins.isAttrs a && a ? Address
    then addrOf a.Address
    else null;

  vmOf = name: vm: host: let
    ev = vm.config.config or {};
  in {
    inherit host;
    ip = addrOf (ev.systemd.network.networks."20-lan".address or null);
    mem = ev.microvm.mem or null;
    vcpu = ev.microvm.vcpu or null;
    autostart = vm.autostart or true;
    tcpPorts = ev.networking.firewall.allowedTCPPorts or [];
    udpPorts = ev.networking.firewall.allowedUDPPorts or [];
    volumes =
      map (v: {
        mountPoint = v.mountPoint or null;
        size = v.size or null;
      })
      (
        if builtins.isList (ev.microvm.volumes or {})
        then ev.microvm.volumes
        else attrValues (ev.microvm.volumes or {})
      );
  };

  # ----------------------------------------------------------------------
  # homectl module option extraction (guarded: module may be absent)
  # ----------------------------------------------------------------------

  homectlOpts = cfg:
    if cfg.options ? lucy.homectl
    then let
      o = cfg.config.lucy.homectl;
      value = {
        inherit (o) enable;
        inherit (o) role;
        agent.plugins = o.agent.plugins;
        api = {
          port = o.api.port;
          artifactsDir = o.api.artifactsDir;
          webDir = o.api.webDir;
          proxy = o.api.proxy;
        };
        ui.navigation = o.ui.navigation;
        inherit (o) rbac;
      };
      t = tryEval (builtins.deepSeq value value);
    in
      if t.success
      then t.value
      else {}
    else {};

  enabled = cfg: (homectlOpts cfg).enable or false;

  apiHost = let
    withRole = filter (n: (homectlOpts configurations.${n}).role or "" == "api") (attrNames configurations);
  in
    if withRole == []
    then null
    else head withRole;

  pluginList = name:
    if enabled configurations.${name}
    then (homectlOpts configurations.${name}).agent.plugins or ["systemd" "journal" "metrics"]
    else [];

  proxyRoutes = let
    cfg =
      if apiHost == null
      then {}
      else homectlOpts configurations.${apiHost};
    proxy =
      if cfg == {}
      then {}
      else cfg.api.proxy or {};
  in
    mapAttrs (n: v: {inherit (v) target;}) proxy;

  uiOpts = let
    cfg =
      if apiHost == null
      then {}
      else homectlOpts configurations.${apiHost};
  in
    if cfg == {}
    then {}
    else cfg.ui or {};

  # ----------------------------------------------------------------------
  # ui generation (structure is Nix data, React only renders)
  # ----------------------------------------------------------------------

  hostNames = attrNames configurations;

  hasVms = (builtins.length (attrNames vmCatalog)) > 0;

  defaultNav =
    [
      {
        label = "Dashboard";
        path = "/";
        page = "dashboard";
      }
      {
        label = "Hosts";
        path = "/hosts";
        page = "hosts";
      }
      {
        label = "Journal";
        path = "/journal";
        page = "journal";
      }
      {
        label = "Terminal";
        path = "/terminal";
        page = "terminal";
      }
      {
        label = "Deploy";
        path = "/deploy";
        page = "deploy";
      }
    ]
    ++ (
      if hasVms
      then [
        {
          label = "VMs";
          path = "/vms";
          page = "vms";
        }
      ]
      else []
    )
    ++ [
      {
        label = "NixOS";
        path = "/nixos";
        page = "nixos";
      }
      {
        label = "Git";
        path = "/git";
        page = "git";
      }
      {
        label = "GitHub";
        path = "/github";
        page = "github";
      }
      {
        label = "Monitoring";
        path = "/monitoring";
        page = "monitoring";
      }
      {
        label = "Network";
        path = "/network";
        page = "network";
      }
      {
        label = "Settings";
        path = "/settings";
        page = "settings";
      }
    ];

  navigation = defaultNav ++ (uiOpts.navigation or []);

  defaultWidgets =
    map (n: {
      type = "host-summary";
      host = n;
      dataSource = "manifest";
    })
    hostNames;

  dashboard = {
    widgets = defaultWidgets ++ (uiOpts.dashboardWidgets or []);
  };

  pageFlags = uiOpts.pages or {};

  featureFlags =
    {
      terminal = true;
      files = true;
      containers = false;
      tailscale = false;
      proxy = proxyRoutes != {};
    }
    // mapAttrs (_: v: v.enabled) pageFlags;

  rbac =
    if apiHost == null || uiOpts == {}
    then [
      {
        role = "admin";
        action = "*";
        resource = "*";
      }
    ]
    else
      (
        if builtins.hasAttr "rbac" (homectlOpts configurations.${apiHost})
        then (homectlOpts configurations.${apiHost}).rbac
        else [
          {
            role = "admin";
            action = "*";
            resource = "*";
          }
        ]
      );

  # ----------------------------------------------------------------------
  # assembly
  # ----------------------------------------------------------------------

  hostCatalog = mapAttrs hostView configurations;

  vmCatalog = let
    perHost = mapAttrs (n: cfg:
      if cfg.options ? microvm
      then mapAttrs (vmName: vm: vmOf vmName vm n) cfg.config.microvm.vms
      else {})
    configurations;
  in
    builtins.foldl' (a: b: a // b) {} (attrValues perHost);

  catalog = {
    roles = mapAttrs (_: r: r.meta or {}) roles;
    bundles = mapAttrs (_: b: b.meta or {}) bundles;
    presets = mapAttrs (_: p: p.meta or {}) presets;
    packages = {
      system = attrNames (import ../data/packages/system.nix {inherit pkgs;});
      home = attrNames (import ../data/packages/home.nix {inherit pkgs;});
    };
  };

  manifest = {
    version = 1;
    hosts = hostCatalog;
    vms = vmCatalog;
    deployNodes =
      mapAttrs (_: n: {
        inherit (n) hostname;
        inherit (n) sshUser;
      })
      deployNodes;
    proxy = proxyRoutes;
    plugins = listToAttrs (map (n: {
        name = n;
        value = pluginList n;
      })
      hostNames);
    inherit catalog;
  };

  ui = {
    inherit navigation;
    inherit dashboard;
    inherit featureFlags;
    inherit rbac;
  };
in {
  inherit manifest ui;
  manifestJson = toJSON manifest;
  uiJson = toJSON ui;
}
