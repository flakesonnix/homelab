{
  config,
  lib,
  ...
}: {
  options.lucy.vesktop = {
    enable = lib.mkEnableOption "Vesktop settings";
  };

  config = lib.mkIf config.lucy.vesktop.enable {
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
