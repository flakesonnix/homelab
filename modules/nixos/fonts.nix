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
    # Installation remains optional; desktop defaults live in profiles/desktop.nix.
    fonts.packages = [pkgs.inter];
  };
}
