{
  applyHost = {
    lib,
    host,
    packagePath,
    basePackagePath,
  }:
    (host.moduleFlags or {})
    // lib.optionalAttrs (host ? packageToggles) (
      lib.setAttrByPath packagePath (builtins.listToAttrs (
        map (name: {
          inherit name;
          value = true;
        })
        host.packageToggles
      ))
    )
    // lib.optionalAttrs (host ? basePackages) (lib.setAttrByPath basePackagePath host.basePackages)
    // (host.settings or {});

  mkHost = host: host;
}
