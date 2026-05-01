let
  projectLib = import ../default.nix;
  inherit (projectLib.core) composition registry validation;

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
    target ? null,
  }:
    map (
      name: let
        role = import (root + "/${name}.nix");
      in
        if target != null && builtins.isAttrs role && builtins.hasAttr target role
        then role.${target} or {}
        else role
    )
    names;

  loadBundles = {
    root,
    names,
    args ? {},
  }:
    map (
      name: let
        value = import (root + "/${name}.nix");
      in
        if builtins.isFunction value
        then value args
        else value
    )
    names;
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
    __root = root;

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
    validationResult = validation.validateHome {
      inherit lib packageRegistry;
      homeRoot = home.__root;
      inherit roleRoot bundleRoot;
      packageData = {
        packageToggles = home.packageToggles or [];
        packageTags = home.packageTags or [];
      };
    };

    validationAssertion = validation.assertValid ({
        inherit lib;
        kind = "home configuration";
      }
      // validationResult);

    resolvedRoles = lib.optionals (roleRoot != null) (loadRoles {
      root = roleRoot;
      names = home.roles or [];
      target = "home";
    });

    resolvedBundleNames = lib.unique (builtins.concatLists (map (role: role.bundles or []) resolvedRoles));
    resolvedBundles = loadBundles {
      root = bundleRoot;
      names = resolvedBundleNames;
      args = {inherit lib;};
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
    builtins.seq validationAssertion (lib.recursiveUpdate baseConfig (mergedHome.settings or {}));
}
