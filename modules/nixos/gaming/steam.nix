{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lucy.gaming;
in {
  config = lib.mkIf cfg.enable {
    hardware.steam-hardware.enable = cfg.steam.enable;
    programs.steam.enable = cfg.steam.enable;
    programs.steam.platformOptimizations.enable = cfg.platformOptimizations;
    programs.gamemode.enable = cfg.gamemode.enable;
    programs.gamescope = {
      inherit (cfg.gamescope) enable;
      inherit (cfg.gamescope) capSysNice;
    };
    environment.systemPackages = lib.optionals cfg.mangohud.enable [pkgs.mangohud];
  };
}
