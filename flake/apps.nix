{
  pkgs,
  system,
  deploy-rs,
  nixfleetPkgs,
  dotfilesLib,
}:
let
  mkApp = description: package: binary: {
    type = "app";
    program = "${package}/bin/${binary}";
    meta.description = description;
  };
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = [ pkgs.nh ];
    text = "nh os switch";
  };
  deploy =
    host:
    pkgs.writeShellApplication {
      name = "deploy-${host}";
      runtimeInputs = [ deploy-rs.packages.${system}.default ];
      text = "deploy .#${host}";
    };
  evalTargets = [
    ".#formatter.x86_64-linux.drvPath"
    ".#devShells.x86_64-linux.default.drvPath"
    ".#apps.x86_64-linux.rebuild.type"
  ];
  check = dotfilesLib.ciScripts.mkCheckApp {
    name = "check";
    inherit evalTargets;
    buildTargets = [
      ".#full-ci-checks"
      ".#checks.x86_64-linux.dotfiles-tests"
    ];
  };
  checkLight = dotfilesLib.ciScripts.mkCheckApp {
    name = "check-light";
    inherit evalTargets;
  };
  checkFull = dotfilesLib.ciScripts.mkCheckApp {
    name = "check-full";
    buildTargets = [ ".#full-ci-checks" ];
  };
  update = pkgs.writeShellApplication {
    name = "update";
    text = "nix flake update";
  };
  manifest = dotfilesLib.ciScripts.mkCheckApp {
    name = "nixfleet-manifest";
    buildTargets = [
      ".#packages.x86_64-linux.nixfleet-manifest"
      ".#packages.x86_64-linux.nixfleet-ui"
    ];
  };
  # Labels for the existing interactive launcher, not a second command registry.
  menuEntries = {
    rebuild = "Rebuild local p53 via nh";
    deploy-p53 = "Deploy p53 via deploy-rs to localhost";
    deploy-mireo = "Deploy mireo via deploy-rs to 10.8.0.1";
    check = "Run evaluation and full CI checks";
    check-light = "Fast eval-surface checks";
    check-full = "Full CI check builds";
    update = "Update flake inputs";
    setup-sops = "Generate sops-nix age key pair";
    topology = "Build network/host topology SVGs";
    nixfleet = "nixfleet CLI (status, health)";
  };
  menu = pkgs.writeShellApplication {
    name = "menu";
    runtimeInputs = [ pkgs.fzf ];
    text = ''
      entries='${
        pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (n: d: "${n}|${d}") menuEntries)
      }'
      choice=$(printf '%s\n' "$entries" | fzf --delimiter='|' --with-nth=2 --prompt='run> ')
      [ -z "$choice" ] && exit 0
      name=''${choice%%|*}
      exec nix run ".#$name"
    '';
  };
in
{
  rebuild = mkApp "Rebuild the p53 host via nh" rebuild "rebuild";
  check = mkApp "Run evaluation and full CI checks" check "check";
  check-light = mkApp "Run light flake surface checks" checkLight "check-light";
  check-full = mkApp "Run full CI check builds" checkFull "check-full";
  update = mkApp "Update flake inputs" update "update";
  deploy-p53 = mkApp "Deploy p53 via deploy-rs to localhost" (deploy "p53") "deploy-p53";
  deploy-mireo = mkApp "Deploy mireo via deploy-rs to 10.8.0.1" (deploy "mireo") "deploy-mireo";
  setup-sops =
    mkApp "Generate sops-nix age key pair" (dotfilesLib.mkSetupSops "setup-sops")
      "setup-sops";
  nixfleet = mkApp "nixfleet CLI (status, health)" nixfleetPkgs.cli "nixfleet";
  nixfleet-manifest = mkApp "Evaluate the nixfleet artifacts" manifest "nixfleet-manifest";
  menu = mkApp "Interactive command launcher (fzf)" menu "menu";
}
