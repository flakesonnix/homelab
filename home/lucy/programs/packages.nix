{ config, pkgs, lib, ... }:

{
  options.lucy.programs = {
    jetbrains-mono = lib.mkEnableOption "JetBrains Mono font";
    nautilus = lib.mkEnableOption "Nautilus file manager";
    comma = lib.mkEnableOption "comma (run programs without installing)";
    android-studio = lib.mkEnableOption "Android Studio";
    fuzzel = lib.mkEnableOption "fuzzel (app launcher)";
  };

  config = {
    home.packages = lib.optionals config.lucy.programs.jetbrains-mono [ pkgs.jetbrains-mono ]
      ++ lib.optionals config.lucy.programs.comma [ pkgs.comma ]
      ++ lib.optionals config.lucy.programs.android-studio [ pkgs.android-studio ]
      ++ lib.optionals config.lucy.programs.fuzzel [ pkgs.fuzzel ]
      ++ lib.optionals config.lucy.programs.nautilus [ pkgs.nautilus ];

    home.sessionVariables = {
      WALLPAPER = "/home/lucy/Pictures/s-l1600.jpg";
    };
  };
}
