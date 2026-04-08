{ config, pkgs, lib, ... }:

{
  options.lucy.programs = {
    jetbrains-mono = lib.mkEnableOption "JetBrains Mono font";
    wpaperd = lib.mkEnableOption "wpaperd wallpaper daemon";
    comma = lib.mkEnableOption "comma (run programs without installing)";
    android-studio = lib.mkEnableOption "Android Studio";
  };

  config = {
    home.packages = lib.optionals config.lucy.programs.jetbrains-mono [ pkgs.jetbrains-mono ]
      ++ lib.optionals config.lucy.programs.wpaperd [ pkgs.wpaperd ]
      ++ lib.optionals config.lucy.programs.comma [ pkgs.comma ]
      ++ lib.optionals config.lucy.programs.android-studio [ pkgs.android-studio ];

    services.wpaperd = lib.mkIf config.lucy.programs.wpaperd {
      enable = true;
      settings.default = {
        path = "${config.home.homeDirectory}/Pictures/s-l1600.jpg";
        scale = "fill";
        mode = "crop";
      };
    };
  };
}
