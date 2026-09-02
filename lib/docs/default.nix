# Docs framework — main entry
{lib, pkgs}: let
  ast = import ./ast.nix;
  domain = import ./domain.nix {inherit lib;};
  validate = import ./validate.nix {inherit lib;};
  markdown = import ./render/markdown.nix {inherit lib;};
  jsonRender = import ./render/json.nix {inherit lib;};
  generate = import ./generate.nix {inherit lib pkgs;};
in {
  inherit ast domain validate markdown jsonRender generate;

  # Convenience: re-export mk* helpers
  inherit (ast) mkDocument mkHeading mkParagraph mkList mkTable mkCodeBlock mkSection mkLink mkReference;
  inherit (domain) mkHost mkService mkModule mkMicroVM mkEntity;
}
