{ lib, config, pkgs, ... }:

let
  nerdFontFamilies = builtins.filter (name: !(builtins.elem name [
    "override"
    "overrideDerivation"
    "recurseForDerivations"
  ])) (builtins.attrNames pkgs.nerd-fonts);
in

{
  options.lucy.waybar.installFonts = lib.mkEnableOption "install Waybar Nerd Fonts system-wide";

  config = lib.mkIf config.lucy.waybar.installFonts {
    fonts.packages = builtins.map (name: pkgs.nerd-fonts.${name}) nerdFontFamilies;
  };
}
