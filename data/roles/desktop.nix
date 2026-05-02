{
  host = {
    moduleFlags = {
      lucy.fonts.inter = true;
      programs.niri.enable = true;
      lucy.waybar.installFonts = true;
    };

    packageTags = ["desktop"];
  };

  home = {
    bundles = ["desktop"];
  };
}
