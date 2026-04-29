{
  mkRegistryModule = {
    lib,
    registry,
  }:
    lib.mapAttrs (_: value: lib.mkEnableOption value.description) registry;

  collectTargetPackages = {
    enabledAttrs,
    registry,
    target,
  }:
    builtins.concatLists (
      map (
        name: let
          entry = registry.${name};
        in
          if enabledAttrs.${name} or false
          then entry.packages.${target} or []
          else []
      ) (builtins.attrNames registry)
    );

  enabledRegistryNames = enabledAttrs: registry:
    builtins.filter (name: enabledAttrs.${name} or false) (builtins.attrNames registry);
}
