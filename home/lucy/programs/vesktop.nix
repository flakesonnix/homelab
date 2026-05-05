{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.vesktop.enable {
    xdg.configFile."vesktop/settings.json" = {
      force = true;
      text = builtins.toJSON {
        arRPC = true;
        discordBranch = "stable";
        minimizeToTray = true;
        splashBackground = config.lib.stylix.colors.withHashtag.base00;
        splashColor = config.lib.stylix.colors.withHashtag.base05;
        staticTitle = true;
      };
    };
  };
}
