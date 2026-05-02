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
      programs.niri.enable = true;
      lucy.waybar.installFonts = true;
    };

    packageTags = ["desktop"];
  };

  home = {
    bundles = ["desktop"];
  };
}
