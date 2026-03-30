{ lib, config, pkgs, ... }:

{
  options.lucy.stylix = {
    enable = lib.mkEnableOption "Stylix theming";
  };

  config = lib.mkIf config.lucy.stylix.enable {
    stylix = {
      enable = true;
      base16Scheme = {
        scheme = "Custom";
        base00 = "1a1520";
        base01 = "2e2334";
        base02 = "52374f";
        base03 = "6c70a8";
        base04 = "7986a3";
        base05 = "a990af";
        base06 = "d8b3cf";
        base07 = "f8f2f7";
        base08 = "de99ac";
        base09 = "bf8c79";
        base0A = "778ad8";
        base0B = "a1a5e0";
        base0C = "b8d4e8";
        base0D = "96656a";
        base0E = "d8b3cf";
        base0F = "52374f";
      };
      targets.waybar.enable = true;
      targets.waybar.font = "monospace";
    };

    gtk = {
      enable = true;
      gtk4.theme = null;
    };
  };
}
