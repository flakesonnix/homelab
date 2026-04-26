{ lib, config, pkgs, ... }:

{
  options.lucy.waybar.installFonts = lib.mkEnableOption "install Waybar Nerd Fonts system-wide";

  config = lib.mkIf config.lucy.waybar.installFonts {
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];
  };
}
