{
  pkgs,
  lib,
  self,
}:
let
  p53 = self.nixosConfigurations.p53.config;
  mireo = self.nixosConfigurations.mireo.config;
  cups = mireo.microvm.vms.cups.config.config;
  home = p53.home-manager.users.lucy;
  opencode = home.programs.opencode;
  cli = home.xdg.configFile."opencode/home-manager-cli.json";
  theme = home.xdg.configFile."opencode/themes/stylix.json";
  configurations =
    (map (host: host.config) (lib.attrValues self.nixosConfigurations))
    ++ (map (vm: vm.config.config) (lib.attrValues mireo.microvm.vms));
  warnings = (lib.concatMap (config: config.warnings) configurations) ++ home.warnings;
  oldWarning =
    warning:
    lib.any (name: lib.hasInfix name warning) [
      "services.avahi.allowInterfaces"
      "services.avahi.publish.enable"
      "services.avahi.publish.userServices"
      "programs.opencode.tui"
    ];
  publishes =
    config:
    config.services.avahi.enable
    && !config.services.avahi.settings.publish.disable-publishing
    && !config.services.avahi.settings.publish.disable-user-service-publishing
    && config.services.avahi.settings.publish.publish-addresses;
  avahiConfig =
    config:
    let
      command = config.systemd.services.avahi-daemon.serviceConfig.ExecStart;
      matched = builtins.match ".* -f ([^ ]+).*" command;
    in
    assert lib.assertMsg (matched != null) "Avahi must pass its generated configuration using -f";
    lib.strings.addContextFrom command (builtins.head matched);
in
assert lib.assertMsg (lib.all publishes [
  p53
  mireo
  cups
]) "Avahi publishing and address advertisement must survive the option migration";
assert
  mireo.services.avahi.settings.server.allow-interfaces == [
    "br0"
    "lo"
  ];
assert !lib.any oldWarning warnings;
assert opencode.enable && opencode.mutableSettings && opencode.tui == { };
assert opencode.cli.theme.name == "stylix";
assert opencode.validateFiles.cli;
assert home.home.sessionVariables ? OPENCODE_CLI_CONFIG_CONTENT;
assert !(home.home.sessionVariables ? OPENCODE_TUI_CONFIG);
assert !(home.xdg.configFile."opencode/cli.json".enable or false);
assert !(home.xdg.configFile."opencode/tui.json".enable or false);
assert !(home.xdg.configFile."opencode/home-manager-tui.json".enable or false);
pkgs.runCommand "config-deprecations-check"
  {
    nativeBuildInputs = [
      pkgs.check-jsonschema
      pkgs.python3
    ];
  }
  ''
    check-jsonschema --schemafile ${opencode.package.passthru.jsonschema.cli} ${cli.source}
    check-jsonschema --schemafile ${opencode.package.passthru.jsonschema.theme} ${theme.source}
    export OPENCODE_CLI_CONFIG_CONTENT="${home.home.sessionVariables.OPENCODE_CLI_CONFIG_CONTENT}"
    python3 - ${cli.source} ${avahiConfig mireo} ${avahiConfig cups} ${avahiConfig p53} <<'PY'
    import configparser
    import json
    import os
    import sys

    with open(sys.argv[1]) as source:
        assert json.loads(os.environ["OPENCODE_CLI_CONFIG_CONTENT"]) == json.load(source)

    for index, path in enumerate(sys.argv[2:]):
        config = configparser.ConfigParser(interpolation=None)
        config.read(path)
        assert not config.getboolean("publish", "disable-publishing")
        assert not config.getboolean("publish", "disable-user-service-publishing")
        assert config.getboolean("publish", "publish-addresses")
        if index == 0:
            assert [name.strip() for name in config.get("server", "allow-interfaces").split(",")] == ["br0", "lo"]
    PY
    touch "$out"
  ''
