{
  applyBundle = {
    lib,
    bundle,
    packagePath,
  }:
    (bundle.moduleFlags or {})
    // lib.optionalAttrs (bundle ? packageToggles) (
      lib.setAttrByPath packagePath (builtins.listToAttrs (
        map (name: {
          inherit name;
          value = true;
        })
        bundle.packageToggles
      ))
    );

  mergeBundles = bundles:
    builtins.foldl' (acc: bundle: acc // bundle) {} bundles;
}
