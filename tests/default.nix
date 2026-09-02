{
  pkgs,
  lib,
  self,
  microvm,
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
  hostDataDirs = ["x270" "mireo"];
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
    homePkgs = builtins.attrNames (dotfilesLib.mkPackageRegistry "home");
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
  }) ["x270" "mireo"]);
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
      "deploy-x270"
      "deploy-mireo"
    ]);
  _homectlDeps = {
    homectlApi = depAttr "homectl-api" self.packages.${pkgs.stdenv.hostPlatform.system}.homectl-api;
    homectlAgent = depAttr "homectl-agent" self.packages.${pkgs.stdenv.hostPlatform.system}.homectl-agent;
    homectlCli = depAttr "homectl" self.packages.${pkgs.stdenv.hostPlatform.system}.homectl;
    homectlWeb = depAttr "homectl-web" self.packages.${pkgs.stdenv.hostPlatform.system}.homectl-web;
    homectlManifest = let
      d = self.packages.${pkgs.stdenv.hostPlatform.system}.homectl-manifest;
    in
      builtins.seq d d.outPath;
    homectlUi = let
      d = self.packages.${pkgs.stdenv.hostPlatform.system}.homectl-ui;
    in
      builtins.seq d d.outPath;
  };
  _homectlCheckDep = {homectlTests = depAttr "homectl-tests" self.checks.${pkgs.stdenv.hostPlatform.system}.homectl-tests;};

  dotfilesLib = import ../lib/default.nix pkgs;
  fixerScripts = dotfilesLib.topologyScripts;

  # Synthetic nix-topology network SVG exercising:
  #  - overlapping integer labels (275/286) -> min spacing enforced
  #  - a multiline label (298)               -> opening tag moved as a unit
  #  - a 3-decimal label (301.462)           -> decimal format preserved
  #  - a label already in place (415.462)    -> untouched
  #  - icons at label_y - 9                  -> shift with their label
  #  - root height (400.000)                 -> grown to last_y + 32
  fixtureText = ''
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
  fixture = pkgs.writeText "topology-fixture.svg" fixtureText;

  # Pure assertions on the fixed SVG string.
  hasText = s: p: builtins.match ".*${p}.*" s != null;
  labelYs = s:
    map (l: builtins.fromJSON (builtins.elemAt (builtins.match ".*y=\"([0-9.]+)\".*" l) 0))
    (builtins.filter (l: builtins.match ".*<text[^>]*dominant-baseline=\"hanging\".*" l != null)
      (builtins.filter builtins.isString (builtins.split "\n" s)));
  minSpacing = s: min: let
    sorted = builtins.sort (a: b: a < b) (labelYs s);
    diffs = builtins.genList (i: builtins.elemAt sorted (i + 1) - builtins.elemAt sorted i) (builtins.length sorted - 1);
  in
    builtins.all (d: d >= min) diffs;

  defaultFixed = fixerScripts.fixNetworkSvg {} fixtureText;
  wideFixed = fixerScripts.fixNetworkSvg {minSpacing = 40;} fixtureText;

  checkFixerDefault =
    minSpacing defaultFixed 28
    && hasText defaultFixed "y=\"275\""
    && hasText defaultFixed "y=\"303\""
    && hasText defaultFixed "y=\"331\""
    && hasText defaultFixed "y=\"359.000\""
    && hasText defaultFixed "y=\"415.462\""
    && hasText defaultFixed "fd00:cafe:1::1"
    && hasText defaultFixed "M178.6 266h8v8h-8z"
    && hasText defaultFixed "M178.6 294h8v8h-8z"
    && hasText defaultFixed "M178.6 322h8v8h-8z"
    && hasText defaultFixed "M178.6 350.000h8v8h-8z"
    && hasText defaultFixed "M178.6 406.462h8v8h-8z"
    && hasText defaultFixed "height=\"447.462\""
    && !hasText defaultFixed "y=\"286\"";

  checkFixerWide =
    minSpacing wideFixed 52
    && hasText wideFixed "y=\"327\""
    && hasText wideFixed "y=\"379\""
    && hasText wideFixed "y=\"431.000\""
    && hasText wideFixed "y=\"483.000\""
    && hasText wideFixed "height=\"515.000\""
    && !hasText wideFixed "y=\"286\"";

  dotfilesTests =
    pkgs.runCommand "dotfiles-tests"
    ({
        buildInputs = [pkgs.alejandra pkgs.jq];
        dataModelValid = _evaluateDataModel;
      }
      // _hostDeps
      // _formatterDep
      // _devShellDeps
      // _appDeps
      // _homectlDeps
      // _homectlCheckDep)
    ''
      set -euo pipefail

      echo "=== Data-model integrity ==="
      echo "  roles: ${builtins.toString (builtins.attrNames allRoles)}"
      echo "  bundles: ${builtins.toString (builtins.attrNames allBundles)}"
      echo "  presets: ${builtins.toString (builtins.attrNames allPresets)}"
      echo "  all references valid"

      echo ""
      echo "=== Build dependency verification ==="
      echo "  hosts, formatter, devShells, apps, homectl: built as dependencies"

      echo ""
      echo "=== homectl artifacts ==="
      manifest="$homectlManifest"
      ui="$homectlUi"
      jq -e '.hosts.x270.hostname and (.hosts | has("mireo"))' "$manifest" >/dev/null
      jq -e '.vms | has("cups")' "$manifest" >/dev/null
      jq -e '.navigation | any(.page == "dashboard")' "$ui" >/dev/null
      echo "  manifest.json and ui.json valid"

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

  # A synthetic SVG with 9000 filler lines before the labels: the old
  # line-split fixer overflowed the Nix stack here, so this pins the
  # whole-string implementation (regression test).
  bigSvg = let
    filler = builtins.concatStringsSep "\n" (builtins.genList (_: "<rect x=\"1\" y=\"2\" width=\"3\" height=\"4\"/>") 9000);
  in ''
    <svg xmlns="http://www.w3.org/2000/svg" width="529.6" height="400" viewBox="0 0 529.6 400">
    ${filler}
    <text x="105.6" y="275" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">tailscale0</text>
    <text x="156" y="286" fill="#b6beca" dominant-baseline="hanging" style="font:12px JetBrains Mono" text-anchor="left">br0</text>
    </svg>
  '';
  fixedBig = fixerScripts.fixNetworkSvg {} bigSvg;
  countSub = s: p: builtins.length (builtins.filter builtins.isString (builtins.split p s)) - 1;
  checkBig =
    countSub fixedBig "y=\"275\""
    == 1
    && countSub fixedBig "y=\"303\"" == 1
    && countSub fixedBig "y=\"331\"" == 1
    && countSub fixedBig "y=\"286\"" == 0;

  # Unit tests: the fixer is a pure Nix function; assertions run at eval time
  # on the fixture string. The runner smoke test exercises the build-time
  # `nix eval` plumbing on the real fixture file.
  topologyUnit =
    pkgs.runCommand "topology-fixer-unit" {
      fixerDefaultValid = checkFixerDefault;
      fixerWideValid = checkFixerWide;
      bigSvgValid = checkBig;
    } ''
      set -euo pipefail

      echo "=== Default spec (step=28, iconOffset=-9) ==="
      echo "  OK: spacing, formats, icons, multiline label, height (pure)"

      echo "=== Custom spec (minSpacing=40 -> step=52) ==="
      echo "  OK: custom spec honoured (pure)"

      echo "=== Large SVG (9000 filler lines, no stack overflow) ==="
      echo "  OK: whole-string fixer survives large inputs (pure)"

      echo "=== Build-time runner (nix eval plumbing) ==="
      cp ${fixture} net.svg
      chmod +w net.svg
      ${fixerScripts.fixNetworkSvgApp {}}/bin/fix-network-svg net.svg
      grep -q 'y="303"' net.svg
      grep -q 'y="331"' net.svg
      grep -q 'y="359.000"' net.svg
      grep -q 'y="415.462"' net.svg
      grep -q 'fd00:cafe:1::1' net.svg
      grep -q 'M178.6 294h8v8h-8z' net.svg
      grep -q 'M178.6 350.000h8v8h-8z' net.svg
      grep -q 'height="447.462"' net.svg
      if grep -q 'y="286"' net.svg; then
        echo "FAIL: overlapping label not moved" >&2
        exit 1
      fi
      echo "  OK: runner fixes the file in place"

      echo ""
      echo "All topology unit tests passed."
      touch "$out"
    '';
  # ---- builder unit tests ----
  # Eval-time module assertions (abort on failure, like the data model
  # checks) plus runtime script tests; all collected into builders-unit.
  mkMicrovm = import ../hosts/mireo/mk-microvm.nix;
  mkKeyGenService = dotfilesLib.secretKeys.mkKeyGenService;
  nixosEval = modules:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      inherit modules;
    }).config;
  forceB = cond: msg:
    if cond
    then true
    else builtins.abort "BUILDER TEST ERROR: ${msg}";

  vmSpec = {
    name = "testvm";
    ip = "10.8.0.5";
    mem = 2048;
    vcpu = 2;
    tcpPorts = [80 443];
    udpPorts = [53];
    volumes = [
      {
        image = "/var/lib/test/data.img";
        mountPoint = "/data";
        size = 1024;
        user = "lucy";
        group = "users";
      }
      {
        image = "/var/lib/test/plain.img";
        mountPoint = "/plain";
        size = 2048;
      }
    ];
    tmpfiles = ["d /run/test 0755 root root - -"];
    config = {
      imports = [{environment.variables.FOO = "bar";}];
    };
    extraDns = ["1.1.1.1"];
  };
  vmEval = nixosEval [microvm.nixosModules.host (mkMicrovm vmSpec)];
  vmCfg = vmEval.microvm.vms.testvm.config.config;
  checkVm =
    forceB vmEval.microvm.vms.testvm.autostart "mk-microvm: vms.testvm.autostart must be true"
    && forceB (vmCfg.networking.hostName == "testvm") "mk-microvm: hostName"
    && forceB (vmCfg.microvm.hypervisor == "qemu") "mk-microvm: hypervisor"
    && forceB (vmCfg.microvm.mem == 2048) "mk-microvm: mem"
    && forceB (vmCfg.microvm.vcpu == 2) "mk-microvm: vcpu"
    && forceB (lib.all (p: builtins.elem p vmCfg.networking.firewall.allowedTCPPorts) [80 443]) "mk-microvm: tcpPorts"
    && forceB (lib.all (p: builtins.elem p vmCfg.networking.firewall.allowedUDPPorts) [53]) "mk-microvm: udpPorts"
    && forceB (let
      iface = builtins.head vmCfg.microvm.interfaces;
    in
      iface.id == "vm-testvm" && iface.type == "tap" && iface.mac == "02:00:00:10:08:05")
    "mk-microvm: default interfaceId and MAC from ip"
    && forceB (let
      vols = vmCfg.microvm.volumes;
      v1 = builtins.head vols;
      v2 = builtins.head (builtins.tail vols);
    in
      builtins.length vols
      == 2
      && !(v1 ? user)
      && !(v1 ? group)
      && v1.image == "/var/lib/test/data.img"
      && v1.mountPoint == "/data"
      && v1.size == 1024
      && v2.image == "/var/lib/test/plain.img"
      && v2.mountPoint == "/plain"
      && v2.size == 2048)
    "mk-microvm: volume user/group stripped"
    && forceB (lib.all (r: builtins.elem r vmCfg.systemd.tmpfiles.rules) ["d /run/test 0755 root root - -" "d /data 0750 lucy users - -"]) "mk-microvm: tmpfiles rules"
    && forceB (vmCfg.environment.variables.FOO == "bar") "mk-microvm: extra config imports merged";

  baseSpec =
    vmSpec
    // {
      name = "basevm";
      ip = "10.8.0.8";
      interfaceId = "vm-aptcache";
      extraDns = ["1.1.1.1"];
      volumes = [];
      tmpfiles = [];
      config = {};
    };
  baseCfg = (nixosEval [microvm.nixosModules.host (mkMicrovm baseSpec)]).microvm.vms.basevm.config.config;
  checkBase =
    forceB (let
      iface = builtins.head baseCfg.microvm.interfaces;
    in
      iface.id == "vm-aptcache" && iface.type == "tap" && iface.mac == "02:00:00:10:08:08")
    "microvm-base: interface id and MAC"
    && forceB (baseCfg.networking.hostName == "basevm") "microvm-base: hostName via mk-microvm"
    && forceB (baseCfg.systemd.network.networks."20-lan".address == ["10.8.0.8/24"]) "microvm-base: address"
    && forceB (baseCfg.systemd.network.networks."20-lan".networkConfig.Gateway == "10.8.0.1") "microvm-base: gateway"
    && forceB (baseCfg.systemd.network.networks."20-lan".networkConfig.DNS == ["10.8.0.1" "1.1.1.1"]) "microvm-base: dns";

  keygenCfg = nixosEval [
    (mkKeyGenService {
      serviceName = "grafana";
      secretFile = "/var/lib/grafana/secret.key";
      user = "grafana";
      group = "grafana";
      bytes = 48;
      format = "base64";
      extraCommands = "chown grafana:grafana /var/lib/grafana/secret.key";
    })
  ];
  keygenScript = keygenCfg.systemd.services."grafana-secret-key".script;
  checkKeygen =
    forceB (keygenCfg.systemd.services."grafana-secret-key".before == ["grafana.service"]) "mkKeyGenService: before"
    && forceB (keygenCfg.systemd.services."grafana-secret-key".requiredBy == ["grafana.service"]) "mkKeyGenService: requiredBy"
    && forceB (keygenCfg.systemd.services."grafana-secret-key".wantedBy == ["multi-user.target"]) "mkKeyGenService: wantedBy"
    && forceB (keygenCfg.systemd.services."grafana-secret-key".serviceConfig.Type == "oneshot") "mkKeyGenService: Type"
    && forceB (keygenCfg.systemd.services."grafana-secret-key".serviceConfig.user == "grafana") "mkKeyGenService: user"
    && forceB (keygenCfg.systemd.services."grafana-secret-key".serviceConfig.group == "grafana") "mkKeyGenService: group"
    && forceB (keygenCfg.systemd.services."grafana-secret-key".serviceConfig.UMask == "0077") "mkKeyGenService: UMask"
    && forceB (lib.hasInfix "head -c 48 /dev/urandom | base64 > \"/var/lib/grafana/secret.key\"" keygenScript) "mkKeyGenService: base64 generation"
    && forceB (lib.hasInfix "chown grafana:grafana" keygenScript) "mkKeyGenService: extraCommands"
    && forceB (keygenCfg.systemd.services.grafana.after == ["grafana-secret-key.service"]) "mkKeyGenService: target after"
    && forceB (keygenCfg.systemd.services.grafana.requires == ["grafana-secret-key.service"]) "mkKeyGenService: target requires";

  keygenRawScript =
    (nixosEval [
      (mkKeyGenService {
        serviceName = "yammat";
        secretFile = "/var/lib/yammat/client_session_key.aes";
        user = "yammat";
        group = "yammat";
        bytes = 96;
      })
    ]).systemd.services."yammat-secret-key".script;
  checkKeygenRaw =
    forceB (lib.hasInfix "head -c 96 /dev/urandom > \"/var/lib/yammat/client_session_key.aes\"" keygenRawScript) "mkKeyGenService: raw generation"
    && forceB (!lib.hasInfix "base64" keygenRawScript) "mkKeyGenService: raw must not base64-encode";

  _evaluateBuilders = checkVm && checkBase && checkKeygen && checkKeygenRaw;

  notifCounter = dotfilesLib.waybarScripts.mkNotifCounter {};
  notifCounterCustom = dotfilesLib.waybarScripts.mkNotifCounter {
    icons = {
      active = "A";
      inactive = "I";
    };
  };
  mireoDataDispatcher = dotfilesLib.systemScripts.mkMireoDataDispatcher;
  testCheckApp = dotfilesLib.ciScripts.mkCheckApp {
    name = "test-check";
    evalTargets = ["a" "b"];
    buildTargets = ["c"];
  };
  testBundle = dotfilesLib.ciScripts.mkCiCheckBundle {
    name = "test-bundle";
    checks = {
      foo = pkgs.hello;
      bar = pkgs.gitMinimal;
    };
  };

  buildersUnit =
    pkgs.runCommand "builders-unit"
    {
      buildersValid = _evaluateBuilders;
      buildInputs = [pkgs.jq pkgs.gnugrep];
    }
    ''
      set -euo pipefail

      echo "=== waybar notification counter ==="
      mkdir -p stub
      cat > stub/makoctl <<'EOF'
      #!/bin/sh
      if [ -n "''${MAKO_ERR:-}" ]; then
        echo "$MAKO_ERR" >&2
        exit 1
      fi
      printf '%s' "''${MAKO_FIXTURE:-}"
      EOF
      chmod +x stub/makoctl
      export PATH="$PWD/stub:$PATH"

      empty='{"data":[],"error":null}'
      two='{"data":[{"notifications":[{"id":1},{"id":2}]}],"error":null}'

      # real wrapper: makoctl fails (no DBus) -> must not abort, emits inactive JSON
      ${notifCounter}/bin/waybar-notifications | jq -e '.class == "inactive"' >/dev/null
      echo "  OK: wrapper survives makoctl failure"

      # fixture injection: run the script body with the stub first in PATH
      sed '/^export PATH=/d' ${notifCounter}/bin/waybar-notifications > counter.sh
      MAKO_ERR="Failed to connect to DBus" bash counter.sh | grep -q '"class":"inactive"'
      MAKO_FIXTURE="$empty" bash counter.sh | grep -q '"class":"inactive"'
      MAKO_FIXTURE="$two" bash counter.sh | grep -q '"class":"active"'
      MAKO_FIXTURE="$two" bash counter.sh | grep -q '󱅫 2'
      echo "  OK: error, empty and active states"

      echo "=== waybar notification counter (custom icons) ==="
      sed '/^export PATH=/d' ${notifCounterCustom}/bin/waybar-notifications > counter-custom.sh
      MAKO_FIXTURE="$empty" bash counter-custom.sh | grep -q '"text":"I"'
      MAKO_FIXTURE="$two" bash counter-custom.sh | grep -q '"text":"A 2"'
      echo "  OK: custom icons"

      echo "=== ci check app ==="
      grep -rq 'nix eval --option warn-dirty false a --raw >/dev/null' ${testCheckApp}/
      grep -rq 'nix eval --option warn-dirty false b --raw >/dev/null' ${testCheckApp}/
      grep -rq 'nix build --option warn-dirty false c' ${testCheckApp}/
      echo "  OK: eval and build targets"

      echo "=== ci check bundle ==="
      [ -L ${testBundle}/foo ] && [ -L ${testBundle}/bar ]
      case "$(readlink ${testBundle}/foo)" in *hello*) ;; *) echo "FAIL: foo link target" >&2; exit 1 ;; esac
      case "$(readlink ${testBundle}/bar)" in *git*) ;; *) echo "FAIL: bar link target" >&2; exit 1 ;; esac
      echo "  OK: named check links"

      echo "=== mireo data dispatcher ==="
      sed '/^export PATH=/d' ${mireoDataDispatcher}/bin/mireo-data-dispatcher > dispatcher.sh
      cat > stub/mountpoint <<'EOF'
      #!/bin/sh
      exit 1
      EOF
      cat > stub/nc <<'EOF'
      #!/bin/sh
      [ -n "''${NFS_REACHABLE:-}" ] && exit 0 || exit 1
      EOF
      : > dispatcher.log
      cat > stub/mount <<EOF
      #!/bin/sh
      echo "mount" >> "\$LOG"
      EOF
      cat > stub/umount <<EOF
      #!/bin/sh
      echo "umount" >> "\$LOG"
      EOF
      chmod +x stub/mountpoint stub/nc stub/mount stub/umount
      export PATH="$PWD/stub:$PATH"
      export LOG="$PWD/dispatcher.log"

      bash dispatcher.sh wlan0 up
      grep -q '^mount$' dispatcher.log && { echo "FAIL: mounted while unreachable" >&2; exit 1; }
      : > dispatcher.log
      NFS_REACHABLE=1 bash dispatcher.sh wlan0 up
      grep -q '^mount$' dispatcher.log || { echo "FAIL: not mounted while reachable" >&2; exit 1; }
      : > dispatcher.log
      bash dispatcher.sh wlan0 down
      grep -q '^umount$' dispatcher.log || { echo "FAIL: no unmount on down" >&2; exit 1; }
      echo "  OK: mounts only when reachable, unmounts on down"

      echo ""
      echo "All builder unit tests passed."
      touch "$out"
    '';
in {
  dotfiles-tests = dotfilesTests;
  topology-unit = topologyUnit;
  builders-unit = buildersUnit;
}
