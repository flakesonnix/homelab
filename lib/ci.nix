pkgs: let
  inherit (pkgs) lib;
  inherit (lib) mkOption types;
  inherit (import ./types.nix {inherit lib;}) checked;
  evalCmd = target: "nix eval --option warn-dirty false ${target} --raw >/dev/null";
  buildCmd = target: "nix build --option warn-dirty false ${target}";
in {
  # Builds a shell app that evaluates/builds the given flake targets.
  # evalTargets/buildTargets are typed data; the script is generated from
  # them.
  mkCheckApp = spec: let
    s = checked (types.submodule {
      options = {
        name = mkOption {type = types.nonEmptyStr;};
        evalTargets = mkOption {type = types.listOf types.nonEmptyStr; default = [];};
        buildTargets = mkOption {type = types.listOf types.nonEmptyStr; default = [];};
      };
    }) spec;
  in
    pkgs.writeShellApplication {
      inherit (s) name;
      text =
        lib.concatStringsSep "\n" (map evalCmd s.evalTargets)
        + lib.optionalString (s.buildTargets != []) "\n"
        + lib.concatStringsSep "\n" (map buildCmd s.buildTargets);
    };

  # Bundles named check derivations into one aggregate derivation.
  mkCiCheckBundle = spec: let
    s = checked (types.submodule {
      options = {
        name = mkOption {type = types.nonEmptyStr; default = "full-ci-checks";};
        checks = mkOption {type = types.attrsOf types.anything;};
      };
    }) spec;
  in
    pkgs.runCommand s.name {} (
      "mkdir -p $out\n"
      + lib.concatStringsSep "\n" (map (c: "ln -s ${c.value} $out/${c.name}") (lib.attrsToList s.checks))
    );
}
