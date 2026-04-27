{ config, pkgs, lib, ... }:

let
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
    android-studio = {
      description = "Android Studio";
      package = pkgs.android-studio;
    };
    fuzzel = {
      description = "fuzzel (app launcher)";
      package = pkgs.fuzzel;
    };
  };
in
{
  options.lucy.programs = lib.mapAttrs (_: value: lib.mkEnableOption value.description) packageOptions;

  config = {
    home.packages = lib.concatMap
      (name:
        lib.optionals config.lucy.programs.${name} [ packageOptions.${name}.package ]
      )
      (lib.attrNames packageOptions);

    home.sessionVariables = {
      WALLPAPER = "/home/lucy/Pictures/s-l1600.jpg";
    };
  };
}
