{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.stylix.enable {
    stylix = {
      polarity = lib.mkDefault "dark";
      targets = {
        waybar.enable = true;
        alacritty.enable = false;
        gtk.enable = true;
        bat.enable = true;
        btop.enable = true;
        fzf.enable = true;
        mako.enable = false;
        rofi.enable = false;
        zathura.enable = false;
        firefox.enable = true;
        thunderbird.enable = true;
      };
    };

    gtk = {
      enable = true;
    };
  };
}
