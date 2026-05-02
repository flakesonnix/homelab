let
  projectLib = import ../default.nix;
  inherit (projectLib.core) composition validation;
  packageFramework = projectLib.framework.package;
  resolveFramework = import ./resolve.nix;

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

    bundles = importData {
      path = root + "/bundles.nix";
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
    roleNames = home.roles or [];
    validationResult = validation.validateHome {
      inherit lib packageRegistry;
      homeRoot = home.__root;
      inherit roleRoot bundleRoot;
      packageData = {
        packageToggles = home.packageToggles or [];
        packageTags = home.packageTags or [];
      };
    };

    resolvedRoles = lib.optionals (roleRoot != null) (loadRoles {
      root = roleRoot;
      names = roleNames;
      target = "home";
    });

    explicitBundles = home.bundles or [];
    roleBundleRefs = resolveFramework.collectRoleRefs "bundles" resolvedRoles;
    resolvedBundleNames = resolveFramework.resolveHomeBundles {
      directBundles = explicitBundles;
      roles = resolvedRoles;
    };
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

    validationAssertion = validation.assertValid ({
        inherit lib;
        kind = "home configuration";
      }
      // validationResult
      // {
        duplicateRoles = validation.findDuplicateNames roleNames;
        duplicateBundles = validation.findDuplicateNames (
          if explicitBundles != []
          then explicitBundles
          else roleBundleRefs
        );
        conflictingModuleFlags = validation.collectModuleFlagConflicts (resolvedRoles ++ resolvedBundles ++ [home]);
        invalidModuleFlags = validation.invalidModuleFlagKeys {
          moduleFlags = mergedHome.moduleFlags or {};
          allowedRoots = ["programs" "services" "xdg" "home" "stylix" "gtk" "dconf" "nix"];
        };
      });

    selectedPackageNames = packageFramework.selectNames {
      inherit lib packageRegistry;
      packageToggles = mergedHome.packageToggles or [];
      packageTags = mergedHome.packageTags or [];
    };

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
