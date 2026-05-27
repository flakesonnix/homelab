{
  pkgs,
  lib,
  self,
}: let
  inherit (lib) mapAttrsToList removeSuffix;
  readNixDir = dir:
    builtins.listToAttrs (map (name: {
        name = removeSuffix ".nix" name;
        value = import (dir + "/${name}");
      }) (builtins.attrNames (lib.filterAttrs (
        n: v:
          v == "regular" && lib.hasSuffix ".nix" n
      ) (builtins.readDir dir))));
  allRoles = readNixDir ../data/roles;
  allBundles = readNixDir ../data/bundles;
  allPresets = readNixDir ../data/presets;
  hostDataDirs = ["omen" "p50" "mireo"];
  homeDataDirs = ["lucy"];

  force = cond: msg:
    if cond
    then true
    else builtins.abort "DATA MODEL ERROR: ${msg}";

  # ---- eval-time data model checks ----
  checkRoleBundles = let
    validBundles = builtins.attrNames allBundles;
  in
    builtins.all builtins.isBool (mapAttrsToList (roleName: role:
      force (builtins.all (b: builtins.elem b validBundles) (role.home.bundles or []))
      "role ${roleName}: home.bundles contains names not in data/bundles/")
    allRoles);

  checkRolePresets = let
    validPresets = builtins.attrNames allPresets;
  in
    builtins.all builtins.isBool (mapAttrsToList (roleName: role:
      force (builtins.all (p: builtins.elem p validPresets) (role.host.presets or []))
      "role ${roleName}: host.presets contains names not in data/presets/")
    allRoles);

  checkRoleTargets = builtins.all builtins.isBool (mapAttrsToList (roleName: role:
    force (builtins.all (t: builtins.elem t ["host" "home"]) (role.meta.targets or []))
    "role ${roleName}: meta.targets has invalid entries; expected one of [host home]")
  allRoles);

  checkRoleDeps = let
    validRoles = builtins.attrNames allRoles;
    checkSide = side: roleName: role: let
      requires = role.meta.requires.${side} or [];
      conflicts = role.meta.conflicts.${side} or [];
    in
      force (builtins.all (d: builtins.elem d validRoles) requires)
      "role ${roleName}: requires.${side} has unknown roles"
      && force (builtins.all (d: builtins.elem d validRoles) conflicts)
      "role ${roleName}: conflicts.${side} has unknown roles";
  in
    builtins.all builtins.isBool (mapAttrsToList (roleName: role:
      checkSide "host" roleName role && checkSide "home" roleName role)
    allRoles);

  checkHostRoles = let
    validRoles = builtins.attrNames allRoles;
    maybeImport = path:
      if builtins.pathExists path
      then import path
      else [];
  in
    builtins.all builtins.isBool (map (host: let
      hostRoles = maybeImport ../data/hosts/${host}/roles.nix;
    in
      force (builtins.all (r: builtins.elem r validRoles) hostRoles)
      "host ${host}: roles.nix contains names not in data/roles/")
    hostDataDirs);

  checkHomeRoles = let
    validRoles = builtins.attrNames allRoles;
  in
    builtins.all builtins.isBool (map (user: let
      homeRoles = import ../data/home/${user}/roles.nix;
    in
      force (builtins.all (r: builtins.elem r validRoles) homeRoles)
      "home/${user}: roles.nix contains names not in data/roles/")
    homeDataDirs);

  checkBundlePkgToggles = let
    homePkgs = builtins.attrNames (import ../data/packages/home.nix {inherit pkgs;});
  in
    builtins.all builtins.isBool (mapAttrsToList (bundleName: bundle:
      force (builtins.all (t: builtins.elem t homePkgs) (bundle.packageToggles or []))
      "bundle ${bundleName}: packageToggles contains names not in data/packages/home.nix")
    allBundles);

  checkBundleTargets = builtins.all builtins.isBool (mapAttrsToList (bundleName: bundle:
    force (builtins.all (t: builtins.elem t ["home"]) (bundle.meta.targets or []))
    "bundle ${bundleName}: meta.targets has invalid entries")
  allBundles);

  checkPresetTargets = builtins.all builtins.isBool (mapAttrsToList (presetName: preset:
    force (builtins.all (t: builtins.elem t ["host"]) (preset.meta.targets or []))
    "preset ${presetName}: meta.targets has invalid entries")
  allPresets);

  _evaluateDataModel =
    checkRoleBundles
    && checkRolePresets
    && checkRoleTargets
    && checkRoleDeps
    && checkHostRoles
    && checkHomeRoles
    && checkBundlePkgToggles
    && checkBundleTargets
    && checkPresetTargets;

  # Derive host/formatting/devShell/app dependencies as string-ref attributes
  # so Nix includes them as build dependencies.
  depAttr = name: value: builtins.trace "dep:${name}" (builtins.seq value name);
  _hostDeps = builtins.listToAttrs (map (host: {
    name = "host-${host}";
    value = depAttr host self.nixosConfigurations.${host}.config.system.build.toplevel;
  }) ["omen" "p50" "mireo" "x61"]);
  _webuiDep = {webui = depAttr "webui" self.packages.${pkgs.system}.webui;};
  _formatterDep = {fmt = depAttr "fmt" self.formatter.${pkgs.system};};
  _devShellDeps = {
    shell-default = depAttr "shell-default" self.devShells.${pkgs.system}.default;
    shell-gtarp = depAttr "shell-gtarp" (self.devShells.${pkgs.system}.gtarp or null);
  };
  _appDeps = builtins.listToAttrs (map (name: {
      inherit name;
      value = depAttr name self.apps.${pkgs.system}.${name}.program;
    }) [
      "rebuild"
      "check"
      "check-light"
      "check-full"
      "update"
      "deploy-omen"
      "deploy-p50"
      "deploy-mireo"
      "deploy-x61"
    ]);
in
  pkgs.runCommand "dotfiles-tests"
  ({
      buildInputs = [pkgs.alejandra];
      dataModelValid = _evaluateDataModel;
    }
    // _hostDeps // _webuiDep // _formatterDep // _devShellDeps // _appDeps)
  ''
    set -euo pipefail

    echo "=== Data-model integrity ==="
    echo "  roles: ${builtins.toString (builtins.attrNames allRoles)}"
    echo "  bundles: ${builtins.toString (builtins.attrNames allBundles)}"
    echo "  presets: ${builtins.toString (builtins.attrNames allPresets)}"
    echo "  all references valid"

    echo ""
    echo "=== Build dependency verification ==="
    echo "  hosts, webui, formatter, devShells, apps: built as dependencies"

    echo ""
    echo "=== Formatting ==="
    src="${toString ../.}"
    if ! alejandra --check "$src" 2>/dev/null; then
      echo "FAIL: Nix files are not formatted. Run: alejandra ."
      exit 1
    fi
    echo "  all Nix files formatted"

    echo ""
    echo "All tests passed."
    touch "$out"
  ''
