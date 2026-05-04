{
  lib,
  config,
  pkgs,
  ...
}: {
  options = {
    lucy.fonts = {
      inter = lib.mkEnableOption "Inter font";
    };
  };

  config = lib.mkIf config.lucy.fonts.inter {
    fonts.packages = [pkgs.inter];

    # Ensure Inter is actually selected by fontconfig in non-GTK apps too.
    fonts.fontconfig.defaultFonts = {
      sansSerif = ["Inter"];
      serif = ["Inter"];
    };
  };
}
