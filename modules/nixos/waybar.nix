{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.waybar;
in {
  options.lucy.waybar = {
    installFonts = lib.mkEnableOption "install Waybar fonts system-wide";

    nerdFonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [pkgs.nerd-fonts.hack pkgs.nerd-fonts.symbols-only];
      description = "Nerd Font families installed for Waybar glyphs";
    };
  };

  config = lib.mkIf cfg.installFonts {
    fonts.packages = cfg.nerdFonts;
  };
}
