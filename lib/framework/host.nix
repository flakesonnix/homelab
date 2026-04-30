let
  mergeHostParts = parts: let
    mergeList = key:
      builtins.concatLists (map (part: part.${key} or []) parts);
    mergeAttrs = key:
      builtins.foldl' (acc: part: acc // (part.${key} or {})) {} parts;
  in {
    moduleFlags = mergeAttrs "moduleFlags";
    packageToggles = mergeList "packageToggles";
    basePackages = mergeList "basePackages";
    settings = mergeAttrs "settings";
  };
in {
  inherit mergeHostParts;

  applyHost = {
    lib,
    host,
    presets ? [],
    packagePath,
    basePackagePath,
  }: let
    mergedHost = mergeHostParts (presets ++ [host]);
  in
    (mergedHost.moduleFlags or {})
    // lib.optionalAttrs (mergedHost ? packageToggles) (
      lib.setAttrByPath packagePath (builtins.listToAttrs (
        map (name: {
          inherit name;
          value = true;
        })
        mergedHost.packageToggles
      ))
    )
    // lib.optionalAttrs (mergedHost ? basePackages) (lib.setAttrByPath basePackagePath mergedHost.basePackages)
    // (mergedHost.settings or {});

  mkHost = host: host;
}
