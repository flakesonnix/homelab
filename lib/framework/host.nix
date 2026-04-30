let
  projectLib = import ../default.nix;
  inherit (projectLib.core) composition;
  loadPresets = {
    root,
    names,
  }:
    map (name: import (root + "/${name}.nix")) names;
in {
  inherit loadPresets;

  mergeHostParts = {
    lib,
    parts,
  }:
    composition.mergeDefinitions {
      inherit lib parts;
      attrFields = ["moduleFlags" "settings"];
      listFields = ["packageToggles" "basePackages" "systemPackages" "fontPackages"];
    };

  applyHost = {
    lib,
    host,
    presets ? [],
    presetRoot ? null,
    packagePath,
    basePackagePath,
    systemPackagePath ? null,
    fontPackagePath ? null,
  }: let
    resolvedPresets =
      presets
      ++ lib.optionals (presetRoot != null) (loadPresets {
        root = presetRoot;
        names = host.presets or [];
      });

    mergedHost = composition.mergeDefinitions {
      inherit lib;
      parts = resolvedPresets ++ [host];
      attrFields = ["moduleFlags" "settings"];
      listFields = ["packageToggles" "basePackages" "systemPackages" "fontPackages"];
    };
  in
    (mergedHost.moduleFlags or {})
    // lib.optionalAttrs (mergedHost ? packageToggles) (
      composition.renderEnabledAttrs {
        inherit lib;
        path = packagePath;
        names = mergedHost.packageToggles;
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
