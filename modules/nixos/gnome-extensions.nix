{
  lib,
  config,
  pkgs,
  ...
}: {
  options = {
    lucy.gnomeExtensions = {
      enable = lib.mkEnableOption "GNOME extensions";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [
          pkgs.gnomeExtensions.dash-to-dock
          pkgs.gnomeExtensions.vicinae
          pkgs.gnomeExtensions.caffeine
          pkgs.gnomeExtensions.user-themes
        ];
        description = "List of GNOME extensions to install";
      };
    };
  };

  config = lib.mkIf config.lucy.gnomeExtensions.enable {
    environment.systemPackages = config.lucy.gnomeExtensions.packages;
  };
}
