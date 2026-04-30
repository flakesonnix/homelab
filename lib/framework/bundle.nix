let
  projectLib = import ../default.nix;
  inherit (projectLib.core) composition;
in {
  applyBundle = {
    lib,
    bundle,
    packagePath,
  }:
    (bundle.moduleFlags or {})
    // lib.optionalAttrs (bundle ? packageToggles) (
      composition.renderEnabledAttrs {
        inherit lib;
        path = packagePath;
        names = bundle.packageToggles;
      }
    );

  mergeBundles = {
    lib,
    bundles,
  }:
    composition.mergeDefinitions {
      inherit lib;
      parts = bundles;
      attrFields = ["moduleFlags" "settings" "home" "programs" "services" "xdg" "nix"];
      listFields = ["packageToggles"];
    };
}
