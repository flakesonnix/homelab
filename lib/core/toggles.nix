{
  mkToggleOptions = lib: registry:
    lib.mapAttrs (_: value: lib.mkEnableOption value.description) registry;

  enabledNames = enabledAttrs:
    builtins.filter (name: enabledAttrs.${name} or false) (builtins.attrNames enabledAttrs);

  onlyEnabled = enabledAttrs: registry:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = registry.${name};
      }) (builtins.filter (name: enabledAttrs.${name} or false) (builtins.attrNames registry))
    );
}
