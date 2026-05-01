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
        splashBackground = "#1a1423";
        splashColor = "#f0d0f5";
        staticTitle = true;
      };
    };
  };
}
