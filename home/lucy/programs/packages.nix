{
  config,
  pkgs,
  lib,
  ...
}: let
  projectLib = import ../../../lib;
  packageOptions = {
    jetbrains-mono = {
      description = "JetBrains Mono font";
      package = pkgs.jetbrains-mono;
    };
    nautilus = {
      description = "Nautilus file manager";
      package = pkgs.nautilus;
    };
    comma = {
      description = "comma (run programs without installing)";
      package = pkgs.comma;
    };
    manix = {
      description = "manix option and API search";
      package = pkgs.manix;
    };
    nix-output-monitor = {
      description = "nix-output-monitor build UI";
      package = pkgs.nix-output-monitor;
    };
    android-studio = {
      description = "Android Studio";
      package = pkgs.android-studio;
    };
  };
in {
  options.lucy.programs = projectLib.mkPackageOptions lib packageOptions;

  config = {
    home.packages = projectLib.getEnabledPackagesBy lib config.lucy.programs packageOptions (value: [value.package]);

    home.sessionVariables = {
      WALLPAPER = "/home/lucy/Pictures/s-l1600.jpg";
    };
  };
}
