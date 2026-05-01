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
        alacritty.enable = true;
        gtk.enable = true;
      };
    };

    gtk = {
      enable = true;
    };
  };
}
