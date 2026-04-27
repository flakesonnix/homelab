{
  lib,
  config,
  ...
}: {
  options.lucy.stylix = {
    enable = lib.mkEnableOption "Stylix theming";
  };

  config = lib.mkIf config.lucy.stylix.enable {
    stylix = {
      enable = true;
      base16Scheme = {
        scheme = "Custom";
        base00 = "11111e";
        base01 = "1a1a2e";
        base02 = "252536";
        base03 = "3a3a50";
        base04 = "5a5a7a";
        base05 = "9090b0";
        base06 = "c0c0d8";
        base07 = "e8e8f0";
        base08 = "ffffff";
        base09 = "a0a0ff";
        base0A = "8080ff";
        base0B = "c0c0ff";
        base0C = "d0d0ff";
        base0D = "a8a8ff";
        base0E = "b0b0ff";
        base0F = "7070ee";
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
