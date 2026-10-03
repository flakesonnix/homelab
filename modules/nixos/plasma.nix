{
  lib,
  config,
  ...
}: {
  options = {
    lucy.plasma = {
      enable = lib.mkEnableOption "KDE Plasma 6 desktop (parallel zu Niri, per greetd-tuigreet wählbar)";
    };
  };

  config = lib.mkIf config.lucy.plasma.enable {
    services.xserver.enable = true;
    services.desktopManager.plasma6.enable = true;

    programs.dconf.enable = true;
    services.gvfs.enable = true;
  };
}
