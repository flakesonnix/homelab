let
  normalizeRoleList = value:
    if builtins.isList value
    then value
    else if builtins.isAttrs value
    then value.roles or []
    else [];

  findMissingFiles = {
    root,
    names,
  }:
    builtins.filter (name: !(builtins.pathExists (root + "/${name}.nix"))) names;

  findMissingNames = {
    known,
    names,
  }:
    builtins.filter (name: !(builtins.elem name known)) names;

  registryTags = registry:
    builtins.attrNames (
      builtins.listToAttrs (
        builtins.concatLists (
          map (
            name:
              map (tag: {
                name = tag;
                value = true;
              }) (registry.${name}.tags or [])
          ) (builtins.attrNames registry)
        )
      )
    );

  collectRolePresetNames = {
    lib,
    roles,
    roleRoot,
    target,
  }:
    lib.unique (
      builtins.concatLists (
        map (
          roleName: let
            role = import (roleRoot + "/${roleName}.nix");
          in
            role.${target}.presets or []
        )
        roles
      )
    );
in {
  validateHost = {
    lib,
    hostRoot,
    roleRoot ? null,
    presetRoot ? null,
    packageRegistry ? null,
    packageData ? null,
  }: let
    rolesFile = hostRoot + "/roles.nix";
    presetsFile = hostRoot + "/presets.nix";
    hostRoles =
      if builtins.pathExists rolesFile
      then import rolesFile
      else [];
    roles = normalizeRoleList hostRoles;
    hostPresets = let
      p =
        if builtins.pathExists presetsFile
        then import presetsFile
        else [];
    in
      if builtins.isList p
      then p
      else [];
    packageInfo =
      if packageData != null
      then packageData
      else {};
    rolePresetNames =
      if roleRoot != null
      then
        collectRolePresetNames {
          inherit lib roles roleRoot;
          target = "host";
        }
      else [];
    allPresetNames = lib.unique (hostPresets ++ rolePresetNames);
    knownPackageNames =
      if packageRegistry != null
      then builtins.attrNames packageRegistry
      else [];
    knownPackageTags =
      if packageRegistry != null
      then registryTags packageRegistry
      else [];
  in {
    missingRoles =
      if roleRoot != null
      then
        findMissingFiles {
          root = roleRoot;
          names = roles;
        }
      else [];
    missingPresets =
      if presetRoot != null
      then
        findMissingFiles {
          root = presetRoot;
          names = allPresetNames;
        }
      else [];
    missingBundles = [];
    missingPackageToggles =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageNames;
          names = packageInfo.packageToggles or [];
        }
      else [];
    missingPackageTags =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageTags;
          names = packageInfo.packageTags or [];
        }
      else [];
  };

  validateHome = {
    lib,
    homeRoot,
    roleRoot ? null,
    bundleRoot ? null,
    packageRegistry ? null,
    packageData ? null,
  }: let
    rolesFile = homeRoot + "/roles.nix";
    homeRoles =
      if builtins.pathExists rolesFile
      then import rolesFile
      else [];
    roles = normalizeRoleList homeRoles;
    packageInfo =
      if packageData != null
      then packageData
      else {};
    resolvedRoles =
      if roleRoot != null
      then map (name: import (roleRoot + "/${name}.nix")) roles
      else [];
    bundleNames = lib.unique (builtins.concatLists (map (role: role.home.bundles or []) resolvedRoles));
    knownPackageNames =
      if packageRegistry != null
      then builtins.attrNames packageRegistry
      else [];
    knownPackageTags =
      if packageRegistry != null
      then registryTags packageRegistry
      else [];
  in {
    missingRoles =
      if roleRoot != null
      then
        findMissingFiles {
          root = roleRoot;
          names = roles;
        }
      else [];
    missingPresets = [];
    missingBundles =
      if bundleRoot != null
      then
        findMissingFiles {
          root = bundleRoot;
          names = bundleNames;
        }
      else [];
    missingPackageToggles =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageNames;
          names = packageInfo.packageToggles or [];
        }
      else [];
    missingPackageTags =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageTags;
          names = packageInfo.packageTags or [];
        }
      else [];
  };

  assertValid = {
    lib,
    kind ? "configuration",
    missingRoles ? [],
    missingPresets ? [],
    missingBundles ? [],
    missingPackageToggles ? [],
    missingPackageTags ? [],
  }: let
    messages =
      lib.optional (missingRoles != []) "  Missing role files: ${builtins.concatStringsSep ", " (map (n: "data/roles/${n}.nix") missingRoles)}"
      ++ lib.optional (missingPresets != []) "  Missing preset files: ${builtins.concatStringsSep ", " (map (n: "data/presets/${n}.nix") missingPresets)}"
      ++ lib.optional (missingBundles != []) "  Missing bundle files: ${builtins.concatStringsSep ", " (map (n: "data/bundles/${n}.nix") missingBundles)}"
      ++ lib.optional (missingPackageToggles != []) "  Unknown package toggles: ${builtins.concatStringsSep ", " missingPackageToggles}"
      ++ lib.optional (missingPackageTags != []) "  Unknown package tags: ${builtins.concatStringsSep ", " missingPackageTags}";
  in
    if messages != []
    then builtins.throw "${kind} validation failed:\n${builtins.concatStringsSep "\n" messages}"
    else null;
}
