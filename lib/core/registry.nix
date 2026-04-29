{
  mkRegistry = entries: entries;

  registryNames = builtins.attrNames;

  registryByTag = tag: registry:
    builtins.listToAttrs (
      builtins.filter (entry: entry != null) (
        map (
          name: let
            value = registry.${name};
          in
            if builtins.elem tag (value.tags or [])
            then {
              inherit name;
              inherit value;
            }
            else null
        ) (builtins.attrNames registry)
      )
    );

  selectRegistryEntries = names: registry:
    builtins.listToAttrs (map (name: {
        inherit name;
        value = registry.${name};
      })
      names);
}
