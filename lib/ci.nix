pkgs: let
  inherit (pkgs) lib;
  evalCmd = target: "nix eval --option warn-dirty false ${target} --raw >/dev/null";
  buildCmd = target: "nix build --option warn-dirty false ${target}";
in {
  # Builds a shell app that evaluates/builds the given flake targets.
  # evalTargets/buildTargets are data; the script is generated from them.
  mkCheckApp = {
    name,
    evalTargets ? [],
    buildTargets ? [],
  }:
    pkgs.writeShellApplication {
      inherit name;
      text =
        lib.concatStringsSep "\n" (map evalCmd evalTargets)
        + lib.optionalString (buildTargets != []) "\n"
        + lib.concatStringsSep "\n" (map buildCmd buildTargets);
    };

  # Bundles named check derivations into one aggregate derivation.
  mkCiCheckBundle = {
    name ? "full-ci-checks",
    checks,
  }:
    pkgs.runCommand name {} (
      "mkdir -p $out\n"
      + lib.concatStringsSep "\n" (map (c: "ln -s ${c.value} $out/${c.name}") (lib.attrsToList checks))
    );
}
