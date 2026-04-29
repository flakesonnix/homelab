{
  attrsFromNames = names: value:
    builtins.listToAttrs (map (name: {
        inherit name value;
      })
      names);

  mergeAttrsList = builtins.foldl' (acc: attrs: acc // attrs) {};

  setTrueByPath = lib: path:
    lib.setAttrByPath path true;

  pickAttrs = names: attrs:
    builtins.listToAttrs (
      builtins.filter (entry: entry != null) (
        map (
          name:
            if builtins.hasAttr name attrs
            then {
              inherit name;
              value = attrs.${name};
            }
            else null
        )
        names
      )
    );

  mapAttrValues = f: attrs:
    builtins.mapAttrs (_: f) attrs;
}
