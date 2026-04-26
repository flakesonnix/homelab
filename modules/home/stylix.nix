{ lib, config, ... }:

{
  options.lucy.stylix = {
    enable = lib.mkEnableOption "Stylix theming";
  };

  config = lib.mkIf config.lucy.stylix.enable {
    stylix = {
      enable = true;
      base16Scheme = {
        scheme = "Custom";
        base00 = "1a1423";
        base01 = "2a2436";
        base02 = "3d2a4d";
        base03 = "5c5875";
        base04 = "817695";
        base05 = "d8b3cf";
        base06 = "f0d0f5";
        base07 = "ffffff";
        base08 = "ff69b4";
        base09 = "c678dd";
        base0A = "dda0dd";
        base0B = "ba55d3";
        base0C = "ffb6c1";
        base0D = "ff1493";
        base0E = "da70d6";
        base0F = "9932cc";
      };
      targets = {
        waybar.enable = true;
        alacritty.enable = true;
        gtk.enable = true;
      };
      image = null;
    };

    gtk = {
      enable = true;
    };
  };
}
