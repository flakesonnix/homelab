{ pkgs }:
{
  formatter = pkgs.writeShellApplication {
    name = "format-nix";
    runtimeInputs = [
      pkgs.gitMinimal
      pkgs.nixfmt
    ];
    text = builtins.readFile ../scripts/format-nix.sh;
  };

  check =
    src:
    pkgs.runCommand "nix-formatting"
      {
        nativeBuildInputs = [
          pkgs.findutils
          pkgs.nixfmt
        ];
        inherit src;
      }
      ''
        find "$src" -type f -name '*.nix' ! -name hardware-configuration.nix -print0 \
          | xargs -0 -r nixfmt --check
        touch "$out"
      '';
}
