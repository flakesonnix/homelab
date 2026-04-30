let
  projectLib = import ../default.nix;
  inherit (projectLib.core) composition registry;

  importData = {
    path,
    args,
    fallback ? {},
  }: let
    value =
      if builtins.pathExists path
      then import path
      else fallback;
  in
    if builtins.isFunction value
    then value args
    else value;

  loadRoles = {
    root,
    names,
  }:
    map (name: import (root + "/${name}.nix")) names;

  loadBundles = {
    root,
    names,
  }:
    map (name: import (root + "/${name}.nix")) names;
in {
  inherit loadRoles loadBundles;

  mkHome = home: home;

  loadHomeDirectory = {
    lib,
    root,
    args ? {},
  }: let
    importedArgs = args // {inherit lib;};
    packageData = importData {
      path = root + "/packages.nix";
      args = importedArgs;
    };
  in {
    roles = importData {
      path = root + "/roles.nix";
      args = importedArgs;
      fallback = [];
    };

    moduleFlags = importData {
      path = root + "/module-flags.nix";
      args = importedArgs;
    };

    packageToggles = packageData.packageToggles or [];
    packageTags = packageData.packageTags or [];

    settings = importData {
      path = root + "/settings.nix";
      args = importedArgs;
    };
  };

  applyHome = {
    lib,
    home,
    roleRoot ? null,
    bundleRoot,
    packageRegistry ? null,
    packagePath,
  }: let
    resolvedRoles = lib.optionals (roleRoot != null) (loadRoles {
      root = roleRoot;
      names = home.roles or [];
    });

    resolvedBundleNames = lib.unique (builtins.concatLists (map (role: role.bundles or []) resolvedRoles));
    resolvedBundles = loadBundles {
      root = bundleRoot;
      names = resolvedBundleNames;
    };

    mergedHome = composition.mergeDefinitions {
      inherit lib;
      parts = resolvedRoles ++ resolvedBundles ++ [home];
      attrFields = ["moduleFlags" "settings" "home" "programs" "services" "xdg" "nix"];
      listFields = ["packageToggles" "packageTags"];
    };

    selectedPackageNames = lib.unique (
      (mergedHome.packageToggles or [])
      ++ lib.optionals (packageRegistry != null) (registry.registryNamesByTags (mergedHome.packageTags or []) packageRegistry)
    );

    baseConfig =
      (mergedHome.moduleFlags or {})
      // lib.optionalAttrs (selectedPackageNames != []) (
        composition.renderEnabledAttrs {
          inherit lib;
          path = packagePath;
          names = selectedPackageNames;
        }
      )
      // lib.optionalAttrs (mergedHome ? home) {inherit (mergedHome) home;}
      // lib.optionalAttrs (mergedHome ? programs) {inherit (mergedHome) programs;}
      // lib.optionalAttrs (mergedHome ? services) {inherit (mergedHome) services;}
      // lib.optionalAttrs (mergedHome ? xdg) {inherit (mergedHome) xdg;}
      // lib.optionalAttrs (mergedHome ? nix) {inherit (mergedHome) nix;};
  in
    lib.recursiveUpdate baseConfig (mergedHome.settings or {});
}
