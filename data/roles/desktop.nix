{
  meta = {
    description = "Desktop environment, GUI apps, and compositor integration";
    requires = {
      host = [];
      home = ["core"];
    };
    conflicts = {
      host = [];
      home = [];
    };
    targets = ["host" "home"];
  };

  host = {
    moduleFlags = {
      lucy.fonts.inter = true;
      programs.niri.enable = false;
      lucy.gnome.enable = true;
      lucy.gnomeExtensions.enable = true;
      lucy.plasma.enable = false;
      lucy.waybar.installFonts = true;
    };

    packageTags = ["desktop"];
  };

  home = {
    bundles = ["desktop"];
  };
}
