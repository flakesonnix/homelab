let
  resolveFramework = import ./resolve.nix;

  readNamedNixFiles = root:
    map (
      name: builtins.replaceStrings [".nix"] [""] name
    ) (builtins.filter (
      name: builtins.match ".*\\.nix" name != null
    ) (builtins.attrNames (builtins.readDir root)));

  targetList = meta: field: target: let
    value = meta.${field} or [];
  in
    if builtins.isList value
    then value
    else if builtins.isAttrs value
    then value.${target} or []
    else [];

  roleEntry = root: name: let
    role = import (root + "/${name}.nix");
    meta = role.meta or {};
  in {
    inherit name;
    description = meta.description or "";
    targets = meta.targets or [];
    presets = role.host.presets or [];
    bundles = role.home.bundles or [];
    requires = {
      host = targetList meta "requires" "host";
      home = targetList meta "requires" "home";
    };
    conflicts = {
      host = targetList meta "conflicts" "host";
      home = targetList meta "conflicts" "home";
    };
  };

  simpleMetaEntry = root: name: let
    item = import (root + "/${name}.nix");
    meta = item.meta or {};
  in {
    inherit name;
    description = meta.description or "";
    targets = meta.targets or [];
  };
in {
  exportMetadata = root: let
    join = xs: builtins.concatStringsSep "," xs;
    renderRole = role:
      builtins.concatStringsSep "\t" [
        "role"
        role.name
        role.description
        (join role.targets)
        (join role.presets)
        (join role.bundles)
        (join role.requires.host)
        (join role.requires.home)
        (join role.conflicts.host)
        (join role.conflicts.home)
      ];
    renderSimple = kind: item:
      builtins.concatStringsSep "\t" [
        kind
        item.name
        item.description
        (join item.targets)
      ];
    roles = map (roleEntry (root + "/data/roles")) (readNamedNixFiles (root + "/data/roles"));
    presets = map (simpleMetaEntry (root + "/data/presets")) (readNamedNixFiles (root + "/data/presets"));
    bundles = map (simpleMetaEntry (root + "/data/bundles")) (readNamedNixFiles (root + "/data/bundles"));
  in
    builtins.concatStringsSep "\n" (
      (map renderRole roles)
      ++ (map (renderSimple "preset") presets)
      ++ (map (renderSimple "bundle") bundles)
    );

  exportPreview = root: let
    roleRoot = root + "/data/roles";
    hostRoot = root + "/data/hosts/omen";
    homeRoot = root + "/data/home/lucy";
    hostRoles = import (hostRoot + "/roles.nix");
    homeRoles = import (homeRoot + "/roles.nix");
    hostPresetFile = hostRoot + "/presets.nix";
    directHostPresets =
      if builtins.pathExists hostPresetFile
      then import hostPresetFile
      else [];
    rolesFor = names: map (name: import (roleRoot + "/${name}.nix")) names;
    hostRoleDefs = rolesFor hostRoles;
    homeRoleDefs = rolesFor homeRoles;
    resolvedHostPresets = resolveFramework.resolveHostPresets {
      directPresets = directHostPresets;
      roles = map (role: role.host or {}) hostRoleDefs;
    };
    resolvedHomeBundles = let
      bundleFile = homeRoot + "/bundles.nix";
      directBundles =
        if builtins.pathExists bundleFile
        then import bundleFile
        else [];
    in
      resolveFramework.resolveHomeBundles {
        inherit directBundles;
        roles = map (role: role.home or {}) homeRoleDefs;
      };
    render = kind: values: builtins.concatStringsSep "\t" [kind (builtins.concatStringsSep "," values)];
  in
    builtins.concatStringsSep "\n" [
      (render "preview-host-roles" hostRoles)
      (render "preview-host-presets" resolvedHostPresets)
      (render "preview-home-roles" homeRoles)
      (render "preview-home-bundles" resolvedHomeBundles)
    ];
}
