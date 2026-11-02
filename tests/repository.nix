{ pkgs, self }:
let
  inherit (pkgs) lib;
  formatting = import ../lib/formatting.nix { inherit pkgs; };
  fleet = import ../nixfleet { inherit pkgs; };
  serviceData = import ../data/services { inherit lib pkgs; };
  storageData = import ../data/storage { inherit lib pkgs; };
  services = import ../lib/services.nix { inherit lib pkgs; };
  reconciliation = import ../lib/reconciliation.nix { inherit lib pkgs; };
  databases = services.mkPostgresDatabases [
    {
      name = "fixture";
      owner = "fixture";
      port = 5432;
      passwordSecret = "database/fixture";
    }
  ];
  reconciler = reconciliation.mkSafeReconciler {
    name = "fixture";
    script = "true";
  };
  appNames = [
    "check"
    "check-full"
    "check-light"
    "deploy-mireo"
    "deploy-p53"
    "menu"
    "nixfleet"
    "nixfleet-manifest"
    "rebuild"
    "setup-sops"
    "update"
  ];
in
assert
  builtins.attrNames self.nixosConfigurations == [
    "mireo"
    "p53"
  ];
assert builtins.attrNames self.apps.${pkgs.stdenv.hostPlatform.system} == appNames;
assert serviceData.serviceNames == builtins.attrNames serviceData.services;
assert (serviceData.getService "postgres").ip == "10.8.0.28";
assert (storageData.getDataDir "fax").path == "/data/fax";
assert builtins.length storageData.tmpfilesRules == builtins.length storageData.dataDirConfigs;
assert lib.all builtins.isString storageData.tmpfilesRules;
assert
  (builtins.head databases).ensureDatabases == [
    {
      name = "fixture";
      owner = "fixture";
      port = 5432;
    }
  ];
assert reconciler.systemd.services.reconcile-fixture.serviceConfig.Restart == "on-failure";
assert lib.all (p: p.tests.unit.drvPath == fleet.tests.drvPath) [
  fleet.api
  fleet.agent
  fleet.cli
];
pkgs.runCommand "repository-tooling"
  {
    nativeBuildInputs = [
      pkgs.gitMinimal
      pkgs.nixfmt
      pkgs.nix
      pkgs.shellcheck
      formatting.formatter
    ];
  }
  ''
    shellcheck ${../scripts/format-nix.sh}
    shellcheck ${../scripts/new-host.sh}

    # Go packages only carry Go source, not unrelated frontend/docs/artifacts.
    test -e ${fleet.api.src}/go.mod
    test -e ${fleet.api.src}/api/main.go
    test ! -e ${fleet.api.src}/docs
    test ! -e ${fleet.api.src}/artifacts
    test ! -e ${fleet.api.src}/web
    test ! -e ${fleet.api.src}/default.nix

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" fixture/nested fixture/untracked fixture/.sops
    cd fixture
    git init -q
    printf '{x=1;}\n' > source.nix
    printf '{y=2;}\n' > 'nested/source with spaces.nix'
    printf 'invalid generated config\n' > nested/hardware-configuration.nix
    printf 'invalid private config\n' > .sops/private.nix
    printf 'invalid untracked config\n' > untracked/build.nix
    printf 'invalid external config\n' > "$TMPDIR/external.nix"
    ln -s "$TMPDIR/external.nix" linked.nix
    git add source.nix nested linked.nix

    if format-nix --check; then
      echo 'formatter check accepted unformatted source' >&2
      exit 1
    fi
    format-nix
    format-nix --check
    grep -Fx '{ x = 1; }' source.nix
    grep -Fx '{ y = 2; }' 'nested/source with spaces.nix'
    grep -Fx 'invalid generated config' nested/hardware-configuration.nix
    grep -Fx 'invalid private config' .sops/private.nix
    grep -Fx 'invalid untracked config' untracked/build.nix
    grep -Fx 'invalid external config' "$TMPDIR/external.nix"

    # Invoking from a subtree must not modify siblings or the repository root.
    printf '{x=3;}\n' > source.nix
    printf '{y=4;}\n' > 'nested/source with spaces.nix'
    (cd nested && format-nix && format-nix --check)
    grep -Fx '{x=3;}' source.nix
    grep -Fx '{ y = 4; }' 'nested/source with spaces.nix'
    if format-nix --unknown; then
      echo 'formatter accepted an unsupported argument' >&2
      exit 1
    fi

    # Scaffolding must survive the official formatter without rewriting the wrong
    # attribute set or allocating a reserved/dynamic address. Work on private copies.
    cd "$TMPDIR"
    mkdir -p scaffolding/hosts/mireo
    cd scaffolding
    cp ${../flake.nix} flake.nix
    cp ${../hosts/mireo/default.nix} hosts/mireo/default.nix
    cp ${../hosts/mireo/vm-ips.nix} hosts/mireo/vm-ips.nix
    cp ${../hosts/mireo/ntp-microvm.nix} hosts/mireo/ntp-microvm.nix
    bash ${../scripts/new-host.sh} host fixture-host
    nix-instantiate --parse flake.nix >/dev/null
    grep -F 'fixture-host-config = mkHost' flake.nix
    grep -F 'fixture-host = fixture-host-config;' flake.nix
    bash ${../scripts/new-host.sh} vm fixture-vm
    grep -F './fixture-vm-microvm.nix' hosts/mireo/default.nix
    grep -F 'ip = "10.8.0.8";' hosts/mireo/fixture-vm-microvm.nix
    nix-instantiate --parse hosts/mireo/default.nix >/dev/null
    bash ${../scripts/new-host.sh} vm another-vm
    grep -F 'ip = "10.8.0.33";' hosts/mireo/another-vm-microvm.nix
    nixfmt --check flake.nix hosts/mireo/default.nix hosts/mireo/*-vm-microvm.nix

    touch "$out"
  ''
