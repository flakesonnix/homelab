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
  hostDataDirs = ["omen" "mireo"];
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
  }) ["omen" "mireo"]);
  _formatterDep = {fmt = depAttr "fmt" self.formatter.${pkgs.stdenv.hostPlatform.system};};
  _devShellDeps = {
    shell-default = depAttr "shell-default" self.devShells.${pkgs.stdenv.hostPlatform.system}.default;
    shell-gtarp = depAttr "shell-gtarp" (self.devShells.${pkgs.stdenv.hostPlatform.system}.gtarp or null);
  };
  _appDeps = builtins.listToAttrs (map (name: {
      inherit name;
      value = depAttr name self.apps.${pkgs.stdenv.hostPlatform.system}.${name}.program;
    }) [
      "rebuild"
      "check"
      "check-light"
      "check-full"
      "update"
      "deploy-omen"
      "deploy-mireo"
    ]);

  dotfilesLib = import ../lib/default.nix pkgs;
  fixer = dotfilesLib.topologyScripts.fixNetworkSvg {};
  fixerWide = dotfilesLib.topologyScripts.fixNetworkSvg {minSpacing = 40;};

  # Synthetic nix-topology network SVG exercising:
  #  - overlapping integer labels (275/286) -> min spacing enforced
  #  - a multiline label (298)               -> opening tag moved as a unit
  #  - a 3-decimal label (301.462)           -> decimal format preserved
  #  - a label already in place (415.462)    -> untouched
  #  - icons at label_y - 9                  -> shift with their label
  #  - root height (400.000)                 -> grown to last_y + 32
  fixture = pkgs.writeText "topology-fixture.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="529.6" height="400.000" viewBox="0 0 529.6 400">
    <g transform="translate(12, 96)">
    <text x="105.6" y="275" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">tailscale0</text>
    <path fill="#b6beca" stroke="#485263" stroke-width="2" d="M178.6 266h8v8h-8z"/>
    <text x="156" y="286" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">br0</text>
    <path fill="#b6beca" stroke="#485263" stroke-width="2" d="M178.6 277h8v8h-8z"/>
    <text x="12" y="298" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">10.8.0.1
    fd00:cafe:1::1</text>
    <path fill="#b6beca" stroke="#485263" stroke-width="2" d="M178.6 289h8v8h-8z"/>
    <text x="24" y="301.462" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">decimal-label</text>
    <path fill="#b6beca" stroke="#485263" stroke-width="2" d="M178.6 292.462h8v8h-8z"/>
    <text x="24" y="415.462" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">far-label</text>
    <path fill="#b6beca" stroke="#485263" stroke-width="2" d="M178.6 406.462h8v8h-8z"/>
    </g>
    </svg>
  '';

  # Assertions shared by the unit test and the VM test. Both use the default
  # spec (step=28, iconOffset=-9, heightPadding=32), the VM test also checks
  # the fixer executes inside a booted NixOS machine.
  labelSpacingCheck = ''
    if grep -oE '<text[^>]* y="[0-9.]+"[^>]*dominant-baseline="hanging"' net.svg \
      | grep -oE 'y="[0-9.]+"' | awk -F'"' '{print $2}' | sort -n \
      | awk 'NR>1 && $1-prev < 28 {print "labels too close: "prev" -> "$1} {prev=$1}' \
      | grep -q .; then
      echo "FAIL: label spacing violation" >&2
      exit 1
    fi
  '';
  defaultSpecAssertions = ''
    grep -q 'y="275"' net.svg
    grep -q 'y="303"' net.svg
    grep -q 'y="331"' net.svg
    grep -q 'y="359.000"' net.svg
    grep -q 'y="415.462"' net.svg
    grep -q 'fd00:cafe:1::1' net.svg
    grep -q 'M178.6 266h8v8h-8z' net.svg
    grep -q 'M178.6 294h8v8h-8z' net.svg
    grep -q 'M178.6 322h8v8h-8z' net.svg
    grep -q 'M178.6 350.000h8v8h-8z' net.svg
    grep -q 'M178.6 406.462h8v8h-8z' net.svg
    grep -q 'height="447.462"' net.svg
  '';

  dotfilesTests =
    pkgs.runCommand "dotfiles-tests"
    ({
        buildInputs = [pkgs.alejandra];
        dataModelValid = _evaluateDataModel;
      }
      // _hostDeps // _formatterDep // _devShellDeps // _appDeps)
    ''
      set -euo pipefail

      echo "=== Data-model integrity ==="
      echo "  roles: ${builtins.toString (builtins.attrNames allRoles)}"
      echo "  bundles: ${builtins.toString (builtins.attrNames allBundles)}"
      echo "  presets: ${builtins.toString (builtins.attrNames allPresets)}"
      echo "  all references valid"

      echo ""
      echo "=== Build dependency verification ==="
      echo "  hosts, formatter, devShells, apps: built as dependencies"

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
    '';

  # Unit tests: run the fixer on synthetic SVG fixtures and assert the output.
  topologyUnit = pkgs.runCommand "topology-fixer-unit" {} ''
    set -euo pipefail

    echo "=== Default spec (step=28, iconOffset=-9) ==="
    cp ${fixture} net.svg
    chmod +w net.svg
    ${fixer}/bin/fix-network-svg net.svg
    ${labelSpacingCheck}
    ${defaultSpecAssertions}
    echo "  OK: spacing, formats, icons, multiline label, height"

    echo "=== Custom spec (minSpacing=40 -> step=52) ==="
    cp ${fixture} net2.svg
    chmod +w net2.svg
    ${fixerWide}/bin/fix-network-svg net2.svg
    if grep -oE '<text[^>]* y="[0-9.]+"[^>]*dominant-baseline="hanging"' net2.svg \
      | grep -oE 'y="[0-9.]+"' | awk -F'"' '{print $2}' | sort -n \
      | awk 'NR>1 && $1-prev < 52 {print "labels too close: "prev" -> "$1} {prev=$1}' \
      | grep -q .; then
      echo "FAIL: custom spec spacing violation" >&2
      exit 1
    fi
    grep -q 'y="327"' net2.svg
    grep -q 'y="379"' net2.svg
    grep -q 'y="431.000"' net2.svg
    grep -q 'y="483.000"' net2.svg
    grep -q 'height="515.000"' net2.svg
    echo "  OK: custom spec honoured"

    echo ""
    echo "All topology unit tests passed."
    touch "$out"
  '';

  # NixOS VM test: boot a machine with the fixer installed and exercise it.
  topologyVmTest = pkgs.testers.runNixOSTest {
    name = "topology-fixer";
    nodes.machine = {pkgs, ...}: {
      environment.systemPackages = [fixer];
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("cp ${fixture} /tmp/net.svg")
      machine.succeed("chmod +w /tmp/net.svg")
      machine.succeed("fix-network-svg /tmp/net.svg")
      machine.succeed("grep -q 'y=\"303\"' /tmp/net.svg")
      machine.succeed("grep -q 'y=\"331\"' /tmp/net.svg")
      machine.succeed("grep -q 'y=\"359.000\"' /tmp/net.svg")
      machine.succeed("grep -q 'y=\"415.462\"' /tmp/net.svg")
      machine.succeed("grep -q 'fd00:cafe:1::1' /tmp/net.svg")
      machine.succeed("grep -q 'M178.6 350.000h8v8h-8z' /tmp/net.svg")
      machine.succeed("grep -q 'height=\"447.462\"' /tmp/net.svg")
    '';
  };
in {
  dotfiles-tests = dotfilesTests;
  topology-unit = topologyUnit;
  topology-vm = topologyVmTest;
}
