{ lib, config, pkgs, ... }:

{
  options.lucy.stylix = {
    enable = lib.mkEnableOption "Stylix theming";
  };

  config = lib.mkIf config.lucy.stylix {
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
      image = pkgs.fetchurl {
        url = "https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=1920";
        sha256 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
      };
    };

    gtk = {
      enable = true;
    };
  };
}
