{
  meta = {
    description = "Base shell, editor, git, and Nix tooling";
    requires.home = [];
    conflicts.home = [];
    targets = ["home"];
  };

  home = {
    bundles = ["core"];
  };
}
