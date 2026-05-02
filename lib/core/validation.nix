let
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

  findMissingFiles = {
    root,
    names,
  }:
    builtins.filter (name: !(builtins.pathExists (root + "/${name}.nix"))) names;
in {
  validateHost = {
    lib,
    hostRoot,
    roleRoot ? null,
    presetRoot ? null,
  }: let
    rolesFile = hostRoot + "/roles.nix";
    presetsFile = hostRoot + "/presets.nix";
    hostRoles =
      if builtins.pathExists rolesFile
      then import rolesFile
      else [];
    roles = hostRoles.roles or [];
    hostPresets = let
      p =
        if builtins.pathExists presetsFile
        then import presetsFile
        else [];
    in
      if builtins.isList p
      then p
      else [];
    rolePresetNames =
      if roleRoot != null
      then
        collectRolePresetNames {
          inherit lib roles roleRoot;
          target = "host";
        }
      else [];
    allPresetNames = lib.unique (hostPresets ++ rolePresetNames);
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
  };

  validateHome = {
    lib,
    homeRoot,
    roleRoot ? null,
    bundleRoot ? null,
  }: let
    rolesFile = homeRoot + "/roles.nix";
    homeRoles =
      if builtins.pathExists rolesFile
      then import rolesFile
      else [];
    roles = homeRoles.roles or [];
    resolvedRoles =
      if roleRoot != null
      then map (name: import (roleRoot + "/${name}.nix")) roles
      else [];
    bundleNames = lib.unique (
      builtins.concatLists (map (role: role.home.bundles or []) resolvedRoles)
    );
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
  };

  assertValid = {
    lib,
    kind ? "configuration",
    missingRoles ? [],
    missingPresets ? [],
    missingBundles ? [],
  }: let
    messages =
      lib.optional (missingRoles != []) "  Missing role files: ${builtins.concatStringsSep ", " (map (n: "data/roles/${n}.nix") missingRoles)}"
      ++ lib.optional (missingPresets != []) "  Missing preset files: ${builtins.concatStringsSep ", " (map (n: "data/presets/${n}.nix") missingPresets)}"
      ++ lib.optional (missingBundles != []) "  Missing bundle files: ${builtins.concatStringsSep ", " (map (n: "data/bundles/${n}.nix") missingBundles)}";
  in
    if messages != []
    then builtins.throw "${kind} validation failed:\n${builtins.concatStringsSep "\n" messages}"
    else null;
}
