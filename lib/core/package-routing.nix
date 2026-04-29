{
  packagesForTarget = target: enabledAttrs: registry:
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

  collectTargetPackages = target: names: registry:
    builtins.concatLists (map (name: registry.${name}.packages.${target} or []) names);
}
