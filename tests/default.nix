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
  _nixfleetDeps = {
    nixfleetApi = depAttr "nixfleet-api" self.packages.${pkgs.stdenv.hostPlatform.system}.nixfleet-api;
    nixfleetAgent = depAttr "nixfleet-agent" self.packages.${pkgs.stdenv.hostPlatform.system}.nixfleet-agent;
    nixfleetCli = depAttr "nixfleet" self.packages.${pkgs.stdenv.hostPlatform.system}.nixfleet;
    nixfleetWeb = depAttr "nixfleet-web" self.packages.${pkgs.stdenv.hostPlatform.system}.nixfleet-web;
    nixfleetManifest = let
      d = self.packages.${pkgs.stdenv.hostPlatform.system}.nixfleet-manifest;
    in
      builtins.seq d d.outPath;
    nixfleetUi = let
      d = self.packages.${pkgs.stdenv.hostPlatform.system}.nixfleet-ui;
    in
      builtins.seq d d.outPath;
  };
  _nixfleetCheckDep = {nixfleetTests = depAttr "nixfleet-tests" self.checks.${pkgs.stdenv.hostPlatform.system}.nixfleet-tests;};

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
      // _nixfleetDeps
      // _nixfleetCheckDep)
    ''
      set -euo pipefail

      echo "=== Data-model integrity ==="
      echo "  roles: ${builtins.toString (builtins.attrNames allRoles)}"
      echo "  bundles: ${builtins.toString (builtins.attrNames allBundles)}"
      echo "  presets: ${builtins.toString (builtins.attrNames allPresets)}"
      echo "  all references valid"

      echo ""
      echo "=== Build dependency verification ==="
      echo "  hosts, formatter, devShells, apps, nixfleet: built as dependencies"

      echo ""
      echo "=== nixfleet artifacts ==="
      manifest="$nixfleetManifest"
      ui="$nixfleetUi"
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

  _evaluateBuilders = checkKeygen && checkKeygenRaw && checkVoip && checkKuma && checkAsteriskFax && checkMopidy && checkMinecraft && checkMicrovmSecretsShares && checkMicrovmHostKeys && checkMicrovmWait && checkEpg;

  # ---- voip module unit tests (eval-time, no secrets, no network) ----
  # NOTE: voip.nix integrates with asterisk.nix (localTest assertion +
  # extraExtensions hook), but asterisk.nix needs the sops-nix module for
  # standalone eval. The stub below provides the touched options; the real
  # co-import is covered by the x270 host eval (flake check).
  asteriskStub = {lib, ...}: {
    options.services.asteriskLocal = {
      enable = lib.mkEnableOption "stub";
      extraExtensions = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
      transport.protocol = lib.mkOption {
        type = lib.types.enum ["udp" "tcp" "tls"];
        default = "udp";
      };
    };
  };
  voipEnabled = nixosEval [
    asteriskStub
    ../modules/nixos/voip.nix
    {
      services.voip.enable = true;
      services.voip.clients.easybell-main = {
        username = "K00000000";
        passwordFile = "/run/secrets/voip/easybell-main";
        did = "004930000000";
        contactUser = "493012345000";
        inboundExtension = "999";
      };
      services.voip.clients.easybell-test = {
        username = "K00000001";
        passwordFile = "/run/secrets/voip/easybell-test";
        did = "004930000001";
        inboundExtension = "999";
      };
      services.voip.clients.eventphone-test = {
        provider = "eventphone";
        username = "4309";
        passwordFile = "/run/secrets/voip/eventphone-test";
        did = "4309";
        inboundExtension = "999";
      };
      services.voip.clients.eventphone-fax-test = {
        provider = "eventphone";
        username = "4310";
        passwordFile = "/run/secrets/voip/eventphone-fax-test";
        did = "4310";
        inboundExtension = null;
        faxDids = ["4310"];
      };
    }
  ];
  voipDisabled = nixosEval [../modules/nixos/voip.nix];
  voipLocal = nixosEval [
    asteriskStub
    ../modules/nixos/voip.nix
    {
      services.asteriskLocal.enable = true;
      services.voip.enable = true;
      services.voip.localTest.enable = true;
      services.voip.clients.testcall = {
        username = "4309";
        passwordFile = "/run/secrets/voip/testcall";
        did = "4309";
        inboundExtension = "999";
        localPatterns = ["_[2-7]XXX"];
      };
    }
  ];
  checkVoip =
    forceB (voipDisabled.services.voip.enable == false) "voip: must be disabled by default"
    && forceB (voipEnabled.services.voip.providers.easybell.registrar == "voip.easybell.de") "voip: easybell registrar default"
    && forceB (voipEnabled.services.voip.providers.eventphone.registrar == "hg.eventphone.de") "voip: eventphone registrar (EPVPN, wiki-verified)"
    && forceB (voipEnabled.systemd.services.voip-check.serviceConfig.Type == "oneshot") "voip: check service is oneshot"
    && forceB (lib.hasInfix "easybell-main" voipEnabled.systemd.services.voip-check.script) "voip: check script covers the client"
    && forceB (voipEnabled.environment.etc."voip/clients/easybell-main.conf".text != "") "voip: client descriptor rendered"
    && forceB (lib.hasInfix "voip.easybell.de" voipEnabled.environment.etc."voip/clients/easybell-main.conf".text) "voip: descriptor carries the registrar"
    && forceB (lib.hasInfix "contact_user=493012345000" voipEnabled.environment.etc."voip/clients/easybell-main.conf".text) "voip: descriptor carries explicit contactUser"
    && forceB (lib.hasInfix "contact_user=004930000001" voipEnabled.environment.etc."voip/clients/easybell-test.conf".text) "voip: contactUser falls back to did"
    && forceB (lib.hasInfix "server_uri=sip:voip.easybell.de" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer carries the registrar"
    && forceB (lib.hasInfix "transport=transport-udp" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer maps to the asteriskLocal transport object"
    && forceB (lib.hasInfix "contact_user=493012345000" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer carries contact_user"
    && forceB (lib.hasInfix "qualify_frequency=60" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer keeps NAT open via qualify"
    && forceB (lib.hasInfix "registrar=hg.eventphone.de" voipEnabled.environment.etc."voip/clients/eventphone-test.conf".text) "voip: second provider renders its own registrar"
    && forceB (lib.hasInfix "server_uri=sip:hg.eventphone.de" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer registers at eventphone"
    && forceB (lib.hasInfix "exten => 4310,1,Goto(fax-in,s,1)" voipEnabled.systemd.services.voip-render-trunks.script) "voip: faxDids route to fax-in"
    && forceB (lib.hasInfix "fax_dids=4310" voipEnabled.environment.etc."voip/clients/eventphone-fax-test.conf".text) "voip: descriptor carries faxDids"
    && forceB (lib.hasInfix "[easybell-main_in]" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer emits the inbound endpoint"
    && forceB (lib.hasInfix "Dial(PJSIP/999,30)" voipEnabled.systemd.services.voip-render-trunks.script) "voip: renderer routes inbound to inboundExtension"
    && forceB (lib.hasInfix "enable=yes" voipEnabled.services.asterisk.confFiles."dnsmgr.conf") "voip: dnsmgr enabled for SRV registrar"
    && forceB (lib.hasInfix "999" voipLocal.services.asteriskLocal.extraExtensions) "voip: localTest appends extension 999 via asteriskLocal"
    && forceB (lib.hasInfix "Dial(PJSIP/testcall/sip:\${EXTEN}@voip.easybell.de)" voipLocal.services.asteriskLocal.extraExtensions) "voip: localPatterns route out via trunk";

  # ---- uptime-kuma-sync module unit tests (eval-time, no server) ----
  kumaEnabled = nixosEval [
    ../modules/nixos/uptime-kuma-sync.nix
    {
      services.uptime-kuma-sync = {
        enable = true;
        passwordFile = "/run/secrets/uptime-kuma/admin-password";
        statusPage.enable = true;
        monitors = {
          grafana = {
            type = "http";
            target = "http://10.8.0.2:3000/";
          };
          aptcache = {
            type = "port";
            target = "10.8.0.8";
            port = 3142;
          };
        };
      };
    }
  ];
  kumaDisabled = nixosEval [../modules/nixos/uptime-kuma-sync.nix];
  # Runtime test for the kuma>=2.1 status-page save backport: runs the real
  # sync function against a stubbed API serving Kuma 2.x shapes (plural
  # `incidents`). Would have caught the NameError that broke saves live.
  kumaSyncPy = pkgs.python3.withPackages (ps: [ps.uptime-kuma-api]);
  kumaSyncSrc = pkgs.runCommand "uptime-kuma-sync-src" {} ''
    sed -n '/^      import argparse$/,/^          sys.exit(main())$/p' ${../modules/nixos/uptime-kuma-sync.nix} | sed 's/^      //' > $out
  '';
  kumaStatusPageTest = pkgs.writeText "kuma-status-page-test.py" ''
    import json
    import sys
    import urllib.request
    from unittest.mock import patch
    from uptime_kuma_api import Event, UptimeKumaApi

    with open(sys.argv[1]) as f:
        src = f.read()
    g = {"__name__": "kuma_sync_test"}
    exec(compile(src, "uptime-kuma-sync.py", "exec"), g)

    # Kuma >= 2.1 shape: plural incidents, no singular incident key.
    R2 = {
        "config": {"id": 7, "title": "Old", "theme": "auto",
                   "showCertificateExpiry": False},
        "incidents": [],
        "publicGroupList": [],
        "maintenanceList": [],
    }

    class FakeResp:
        def __enter__(self):
            return self
        def __exit__(self, *a):
            return False
        def read(self):
            return json.dumps(R2).encode()

    # version is a read-only property on the real class: drive its real
    # builder with a version-carrying namespace instead of subclassing.
    import types
    _versioned = types.SimpleNamespace(version="2.4.0")

    class FakeApi:
        def __init__(self):
            self.calls = []
            self.tag_ids = {}
            self._event_data = {Event.STATUS_PAGE_LIST: {
                "7": {"slug": "homelab", "id": 7}}}
        def _build_status_page_data(self, **kwargs):
            return UptimeKumaApi._build_status_page_data(_versioned, **kwargs)
        def get_status_pages(self):
            return list(self._event_data[Event.STATUS_PAGE_LIST].values())
        def get_tags(self):
            return [{"id": i, "name": n} for n, i in self.tag_ids.items()]
        def add_tag(self, **kwargs):
            self.calls.append(("addTag", (kwargs,)))
            self.tag_ids[kwargs["name"]] = 100 + len(self.tag_ids)
            return {"id": self.tag_ids[kwargs["name"]],
                    "name": kwargs["name"]}
        def add_monitor_tag(self, tag_id, monitor_id, value=""):
            self.calls.append(("addMonitorTag", (tag_id, monitor_id,
                                                 value)))
            return {"msg": "Added Successfully."}
        def _call(self, method, *args):
            self.calls.append((method, args))
            if method == "getStatusPage":
                return {"config": {"id": 7, "slug": "homelab"}}
            if method == "saveStatusPage":
                return {"msg": "OK"}
            raise AssertionError(f"unexpected api call: {method}")

    page = {"slug": "homelab", "title": "Homelab Status",
            "description": "d", "monitors": ["a", "b", "ghost"]}
    live = {"a": 10, "b": 20}
    existing = {"a": {"tags": []}, "b": {"tags": []}}
    desired = {"a": {"group": "Remote", "target": "10.8.0.9",
                     "tags": {"role": "metrics"}},
               "b": {"target": "http://10.8.0.2:3000/"}}

    api = FakeApi()
    with patch.object(urllib.request, "urlopen", return_value=FakeResp()):
        g["sync_status_page"](api, "http://10.8.0.9:3001", page, live,
                              desired, False)
    saved = [c for c in api.calls if c[0] == "saveStatusPage"]
    assert len(saved) == 1, f"expected one save, got: {api.calls}"
    slug_, config, icon, groups = saved[0][1][0]
    assert slug_ == "homelab", slug_
    assert config["id"] == 7, config
    assert config["title"] == "Homelab Status", config
    assert config["analyticsType"] is None, config
    assert groups == [{"name": "Homelab", "weight": 1,
                       "monitorList": [{"id": 20}]},
                      {"name": "Remote", "weight": 2,
                       "monitorList": [{"id": 10}]}], groups
    g["sync_monitor_tags"](api, desired, live, existing, False)
    assert api.tag_ids == {"target": 100, "role": 101}, api.tag_ids
    assigned = {(c[1][0], c[1][1], c[1][2]) for c in api.calls
                if c[0] == "addMonitorTag"}
    assert assigned == {(100, 10, "10.8.0.9"), (101, 10, "metrics"),
                        (100, 20, "http://10.8.0.2:3000/")}, assigned

    dry = FakeApi()
    with patch.object(urllib.request, "urlopen", return_value=FakeResp()):
        g["sync_status_page"](dry, "http://10.8.0.9:3001", page, live,
                              desired, True)
    assert not [c for c in dry.calls if c[0] == "saveStatusPage"], dry.calls
    g["sync_monitor_tags"](dry, desired, live, existing, True)
    assert not [c for c in dry.calls if c[0] in ("addTag", "addMonitorTag")], dry.calls
    print("kuma status page v2 save: OK")
  '';
  checkKuma =
    forceB (kumaDisabled.services.uptime-kuma-sync.enable == false) "kuma: must be disabled by default"
    && forceB (kumaEnabled.systemd.services.uptime-kuma-sync.serviceConfig.Type == "oneshot") "kuma: sync service is oneshot"
    && forceB (kumaEnabled.systemd.timers.uptime-kuma-sync.timerConfig.OnCalendar == "daily") "kuma: daily convergence timer"
    && forceB (kumaEnabled.systemd.timers.uptime-kuma-sync.timerConfig.OnBootSec == "10m") "kuma: boot-delayed convergence (no switch-time race)"
    && forceB (kumaEnabled.systemd.services.uptime-kuma-sync.wantedBy == []) "kuma: sync never blocks switch/rollback (timer-driven only)"
    && forceB (lib.hasInfix "http://10.8.0.9:3001" kumaEnabled.systemd.services.uptime-kuma-sync.script) "kuma: script targets the API"
    && forceB (lib.hasInfix "uptime-kuma-monitors.json" kumaEnabled.systemd.services.uptime-kuma-sync.script) "kuma: monitor data wired into service"
    && forceB (lib.hasInfix "--status-page" kumaEnabled.systemd.services.uptime-kuma-sync.script) "kuma: status page wired into service"
    && forceB (kumaEnabled.services.uptime-kuma-sync.monitors.grafana.group == "Homelab") "kuma: monitor group defaults to Homelab"
    && forceB (kumaEnabled.services.uptime-kuma-sync.monitors.grafana.tags == {}) "kuma: monitor tags default to empty"
    && forceB (kumaEnabled.systemd.services.uptime-kuma-sync.serviceConfig.Restart == "on-failure") "kuma: retries transient login flakes"
    && forceB (kumaEnabled.systemd.services.uptime-kuma-sync.unitConfig.StartLimitBurst == 3) "kuma: bounded retries, no infinite loop";

  # ---- mireo microvm secrets-share guard (regression 2026-10-04) ----
  # A virtiofs share whose host source dir doesn't exist kills QEMU at
  # start (socket connect refused) and fails the whole switch + rollback.
  # These VMs have no host sops secrets yet, so their specs must not
  # declare a share with source /run/secrets/<name> (guest-side staging
  # scripts referencing the path are fine — only the share breaks QEMU).
  # Re-adding a share requires landing the host secret in the same commit
  # — then drop the name from this list.
  secretlessVMs = ["cloud" "communication" "documents" "media" "sync"];
  checkMicrovmSecretsShares = builtins.all builtins.isBool (map (
      vm:
        forceB (!(lib.hasInfix "source = \"/run/secrets/${vm}\"" (builtins.readFile ../hosts/mireo/${vm}-microvm.nix)))
        "microvm ${vm}: no share with source /run/secrets/${vm} without host sops secrets (breaks QEMU at switch)"
    )
    secretlessVMs);

  # ---- microvm stable host keys (no rotation on rebuild) ----
  hostKeysCfg = nixosEval [
    microvm.nixosModules.microvm
    (import ../hosts/mireo/microvm-base.nix {
      name = "testvm";
      ip = "10.8.0.99";
      interfaceId = "vm-testvm";
    })
  ];
  checkMicrovmHostKeys =
    forceB (hostKeysCfg.services.openssh.hostKeys
      == [
        {
          path = "/run/vm-host-keys/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ]) "microvm: stable hostKeys replace ephemeral defaults"
    && forceB (lib.any (s: (s.tag or "") == "ssh-host-keys" && s.source == "/var/lib/microvms/testvm/ssh-host-keys") hostKeysCfg.microvm.shares) "microvm: host key share wired to per-VM host dir";

  # ---- microvm virtiofsd settle gate (no QEMU-vs-socket race) ----
  waitCfg = nixosEval [
    microvm.nixosModules.host
    ../hosts/mireo/microvm-wait.nix
    ../hosts/mireo/dns-microvm.nix
    ../modules/nixos/lucy-services.nix
    ../modules/nixos/dns-adguard.nix
  ];
  checkMicrovmWait =
    forceB (waitCfg.systemd.services."microvm@dns".serviceConfig.ExecStartPre != []) "microvm: dns gated on settled virtiofsd"
    && forceB (lib.any (c: lib.hasInfix "microvm-wait-virtiofsd dns" c) waitCfg.systemd.services."microvm@dns".serviceConfig.ExecStartPre) "microvm: gate passes the VM name"
    && forceB (lib.hasInfix "/proc/net/unix" (builtins.readFile ../hosts/mireo/microvm-wait.nix)) "microvm: bound sockets read from kernel (connect-probes suicide virtiofsd)"
    && forceB (!(lib.hasInfix "UNIX-CONNECT" (builtins.readFile ../hosts/mireo/microvm-wait.nix))) "microvm: no connect-probes (killed all daemons, 2026-10-06)"
    && forceB (!(lib.hasInfix "supervisorctl" (builtins.readFile ../hosts/mireo/microvm-wait.nix))) "microvm: no supervisorctl (unusable without section, failed all VMs)";

  # ---- mopidy module unit tests (eval-time, no audio hardware) ----
  mopidyEnabled = nixosEval [
    sopsStub
    ../modules/nixos/lucy-services.nix
    ../modules/nixos/mopidy.nix
    {
      lucy.services.mopidy.enable = true;
      sops.placeholder."mopidy/jellyfin-password" = "/run/secrets/mopidy/jellyfin-password";
    }
  ];
  mopidyDisabled = nixosEval [
    sopsStub
    ../modules/nixos/lucy-services.nix
    ../modules/nixos/mopidy.nix
  ];
  checkMopidy =
    forceB (mopidyDisabled.lucy.services.mopidy.enable == false) "mopidy: must be disabled by default"
    && forceB (mopidyEnabled.services.mopidy.enable == true) "mopidy: service enabled"
    && forceB (builtins.elem pkgs.mopidy-mpd mopidyEnabled.services.mopidy.extensionPackages) "mopidy: MPD protocol for M.A.L.P./mpc"
    && forceB (builtins.elem pkgs.mopidy-local mopidyEnabled.services.mopidy.extensionPackages) "mopidy: local files backend"
    && forceB (builtins.elem pkgs.mopidy-jellyfin mopidyEnabled.services.mopidy.extensionPackages) "mopidy: jellyfin backend"
    && forceB (builtins.elem pkgs.mopidy-iris mopidyEnabled.services.mopidy.extensionPackages) "mopidy: iris web client"
    && forceB (mopidyEnabled.services.mopidy.settings.mpd.hostname == "10.8.0.1") "mopidy: MPD on LAN, not 0.0.0.0"
    && forceB (mopidyEnabled.services.mopidy.settings.http.hostname == "127.0.0.1") "mopidy: HTTP loopback only (Caddy in front)"
    && forceB (lib.hasInfix "alsasink" mopidyEnabled.services.mopidy.settings.audio.output) "mopidy: direct ALSA output (no PipeWire)"
    && forceB (lib.hasInfix "hw:CARD=CODEC" mopidyEnabled.services.mopidy.settings.audio.output) "mopidy: stable ALSA device (no hw:N,M)"
    && forceB (mopidyEnabled.services.mopidy.settings.local.media_dir == "/data/Jellyfin/Music") "mopidy: music on /data"
    && forceB (builtins.elem "audio" mopidyEnabled.users.users.mopidy.extraGroups) "mopidy: audio group for USB interface"
    && forceB (lib.hasInfix "snd-usb-audio" (builtins.toString mopidyEnabled.boot.kernelModules)) "mopidy: USB audio module loaded"
    && forceB (builtins.elem 6600 mopidyEnabled.networking.firewall.interfaces.wg0.allowedTCPPorts) "mopidy: MPD port open on VPN"
    && forceB (!(mopidyDisabled.systemd.services ? mopidy)) "mopidy: no service when disabled";

  # ---- epg-refresh unit tests (must never block switch/rollback) ----
  epgEnabled = nixosEval [
    sopsStub
    ../modules/nixos/epg-refresh.nix
    {
      services.epg-refresh.enable = true;
      services.epg-refresh.apiTokenFile = "/run/secrets/jellyfin/epg-api-token";
    }
  ];
  checkEpg =
    forceB (epgEnabled.systemd.services.epg-refresh.wantedBy == []) "epg: never wanted by multi-user (timer-driven only)"
    && forceB (epgEnabled.systemd.timers.epg-refresh.timerConfig.OnCalendar == "daily") "epg: daily convergence timer";

  # ---- minecraft module unit tests (eval-time, no game) ----
  minecraftEnabled = nixosEval [
    ../modules/nixos/lucy-services.nix
    ../modules/nixos/minecraft.nix
    {lucy.services.minecraft.enable = true;}
  ];
  minecraftDisabled = nixosEval [
    ../modules/nixos/lucy-services.nix
    ../modules/nixos/minecraft.nix
  ];
  checkMinecraft =
    forceB (minecraftDisabled.lucy.services.minecraft.enable == false) "minecraft: must be disabled by default"
    && forceB (minecraftEnabled.systemd.services.minecraft.wantedBy == ["multi-user.target"]) "minecraft: service wanted by multi-user"
    && forceB (minecraftEnabled.systemd.services.minecraft.serviceConfig.User == "lucy") "minecraft: service runs as lucy"
    && forceB (minecraftEnabled.systemd.services.minecraft.serviceConfig.WorkingDirectory == "/home/lucy/mcserver") "minecraft: runs in ~/mcserver"
    && forceB (lib.hasInfix "nogui" minecraftEnabled.systemd.services.minecraft.serviceConfig.ExecStart) "minecraft: headless flag present"
    && forceB (lib.hasInfix "server.jar" minecraftEnabled.systemd.services.minecraft.serviceConfig.ExecStart) "minecraft: starts server.jar"
    && forceB (lib.hasInfix "temurin-jre-bin-25" minecraftEnabled.systemd.services.minecraft.serviceConfig.ExecStart) "minecraft: Java 25 for Paper 26.x"
    && forceB (minecraftEnabled.systemd.services.minecraft.serviceConfig.Restart == "on-failure") "minecraft: restarts only on crash"
    && forceB (lib.hasInfix "minecraft.service" minecraftEnabled.security.polkit.extraConfig) "minecraft: lucy polkit rule present"
    && forceB (!(minecraftDisabled.systemd.services ? minecraft)) "minecraft: no service when disabled";

  # ---- asterisk fax unit tests (eval-time, no calls) ----
  # NOTE: asterisk.nix touches sops options (guarded, but this nixpkgs
  # checks option paths structurally) — same stub pattern as asteriskStub.
  sopsStub = {lib, ...}: {
    options.sops = {
      secrets = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      placeholder = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      templates = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      defaultSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };
  };
  faxEnabled = nixosEval [
    sopsStub
    ../modules/nixos/asterisk.nix
    {
      services.asteriskLocal.enable = true;
      services.asteriskLocal.fax = {
        enable = true;
        inboxDir = "/tmp/fax-inbox-test";
      };
      services.asteriskLocal.faxSend = {
        enable = true;
        outboxDir = "/tmp/fax-outbox-test";
        queuedDir = "/tmp/fax-queued-test";
      };
    }
  ];
  faxVanilla = nixosEval [
    sopsStub
    ../modules/nixos/asterisk.nix
    {services.asteriskLocal.enable = true;}
  ];
  checkAsteriskFax =
    forceB (faxEnabled.services.asterisk.confFiles ? "udptl.conf") "fax: udptl.conf rendered when enabled"
    && forceB (lib.hasInfix "udptlstart=4000" faxEnabled.services.asterisk.confFiles."udptl.conf") "fax: UDPTL range present"
    && forceB (!(faxVanilla.services.asterisk.confFiles ? "udptl.conf")) "fax: no udptl.conf when disabled"
    && forceB (faxEnabled.services.asterisk.package.outPath != faxVanilla.services.asterisk.package.outPath) "fax: spandsp package override active"
    && forceB (lib.any (r: lib.hasInfix "/tmp/fax-inbox-test" r) faxEnabled.systemd.tmpfiles.rules) "fax: inbox dir rule present"
    && forceB (faxEnabled.systemd.services.fax-poller.serviceConfig.Type == "oneshot") "fax: poller is oneshot"
    && forceB (faxEnabled.systemd.timers.fax-poller.timerConfig.OnUnitActiveSec == "2min") "fax: poller runs every 2min";

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

      echo "=== kuma status page save (v2 backport) ==="
      ${kumaSyncPy}/bin/python3 ${kumaStatusPageTest} ${kumaSyncSrc}
      echo "  OK: incidents-tolerant save with analyticsType, dry-run clean"

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
