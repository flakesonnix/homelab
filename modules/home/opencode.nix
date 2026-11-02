{
  lib,
  config,
  ...
}:
let
  cfg = config.programs.opencode;
  isOpenCode2 = cfg.package == null || lib.versionAtLeast (lib.getVersion cfg.package) "2.0.0";
  pathExports = ''
    export PATH="${config.home.homeDirectory}/.opencode/bin:$PATH"
    export PATH="$(npm prefix -g)/bin:$PATH"
  '';
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.bash.initExtra = pathExports;
        programs.zsh.initContent = pathExports;
      }
      (lib.mkIf (isOpenCode2 && config.stylix.enable && config.stylix.targets.opencode.enable) {
        programs.opencode = {
          # The pinned Stylix target still selects its palette through V1's
          # tui.theme. Keep the generated theme, but select it through V2's CLI.
          tui = lib.mkForce { };
          cli.theme.name = lib.mkDefault "stylix";

          # V2 owns cli.json. Use the generated inline overlay rather than
          # replacing an existing app-owned file or losing other UI settings.
          mutableSettings = lib.mkDefault true;
          validateFiles.cli = lib.mkDefault (
            cfg.package != null && (cfg.package.passthru.jsonschema.cli or null) != null
          );
        };
      })
    ]
  );
}
