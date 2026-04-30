{
  host = {
    moduleFlags = {
      lucy.fonts.inter = true;
      lucy.niri.enable = true;
      lucy.waybar.installFonts = true;
    };

    packageTags = ["desktop"];
  };

  home = {
    bundles = ["desktop"];
  };
}
