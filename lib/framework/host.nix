let
  projectLib = import ../default.nix;
  inherit (projectLib.core) composition;
  inherit (projectLib.core) registry;

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

  loadPresets = {
    root,
    names,
  }:
    map (name: import (root + "/${name}.nix")) names;

  loadRoles = {
    root,
    names,
  }:
    map (name: import (root + "/${name}.nix")) names;
in {
  inherit loadPresets loadRoles;

  loadHostDirectory = {
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
    presets = importData {
      path = root + "/presets.nix";
      args = importedArgs;
      fallback = [];
    };

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
    basePackages = packageData.basePackages or [];
    systemPackages = packageData.systemPackages or [];
    fontPackages = packageData.fontPackages or [];

    settings = lib.foldl' lib.recursiveUpdate {} [
      (importData {
        path = root + "/settings.nix";
        args = importedArgs;
      })
      (importData {
        path = root + "/power.nix";
        args = importedArgs;
      })
      (importData {
        path = root + "/services.nix";
        args = importedArgs;
      })
    ];
  };

  mergeHostParts = {
    lib,
    parts,
  }:
    composition.mergeDefinitions {
      inherit lib parts;
      attrFields = ["moduleFlags" "settings"];
      listFields = ["packageToggles" "packageTags" "basePackages" "systemPackages" "fontPackages"];
    };

  applyHost = {
    lib,
    host,
    presets ? [],
    presetRoot ? null,
    roleRoot ? null,
    packageRegistry ? null,
    packagePath,
    basePackagePath,
    systemPackagePath ? null,
    fontPackagePath ? null,
  }: let
    resolvedRoles = lib.optionals (roleRoot != null) (loadRoles {
      root = roleRoot;
      names = host.roles or [];
    });

    resolvedPresetNames = lib.unique (
      (host.presets or [])
      ++ builtins.concatLists (map (role: role.presets or []) resolvedRoles)
    );

    resolvedPresets =
      presets
      ++ lib.optionals (presetRoot != null) (loadPresets {
        root = presetRoot;
        names = resolvedPresetNames;
      });

    mergedHost = composition.mergeDefinitions {
      inherit lib;
      parts = resolvedRoles ++ resolvedPresets ++ [host];
      attrFields = ["moduleFlags" "settings"];
      listFields = ["packageToggles" "packageTags" "basePackages" "systemPackages" "fontPackages"];
    };

    selectedPackageNames = lib.unique (
      (mergedHost.packageToggles or [])
      ++ lib.optionals (packageRegistry != null) (registry.registryNamesByTags (mergedHost.packageTags or []) packageRegistry)
    );
  in
    (mergedHost.moduleFlags or {})
    // lib.optionalAttrs (selectedPackageNames != []) (
      composition.renderEnabledAttrs {
        inherit lib;
        path = packagePath;
        names = selectedPackageNames;
      }
    )
    // composition.renderOptionalPath {
      inherit lib;
      path = basePackagePath;
      value = mergedHost.basePackages or null;
    }
    // composition.renderOptionalPath {
      inherit lib;
      path = systemPackagePath;
      value =
        if systemPackagePath == null
        then null
        else mergedHost.systemPackages or [];
    }
    // composition.renderOptionalPath {
      inherit lib;
      path = fontPackagePath;
      value =
        if fontPackagePath == null
        then null
        else mergedHost.fontPackages or [];
    }
    // (mergedHost.settings or {});

  mkHost = host: host;
}
