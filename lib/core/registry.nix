let
  registryNamesByTag = tag: registry:
    builtins.attrNames (builtins.listToAttrs (
      builtins.filter (entry: entry != null) (
        map (
          name: let
            value = registry.${name};
          in
            if builtins.elem tag (value.tags or [])
            then {
              inherit name;
              value = true;
            }
            else null
        ) (builtins.attrNames registry)
      )
    ));
in {
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

  inherit registryNamesByTag;

  registryNamesByTags = tags: registry:
    builtins.foldl' (
      acc: tag:
        acc ++ (registryNamesByTag tag registry)
    ) []
    tags;

  selectRegistryEntries = names: registry:
    builtins.listToAttrs (map (name: {
        inherit name;
        value = registry.${name};
      })
      names);
}
