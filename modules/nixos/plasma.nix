{
  lib,
  config,
  pkgs,
  ...
}: {
  options = {
    lucy.plasma = {
      enable = lib.mkEnableOption "KDE Plasma 6 desktop (parallel zu Niri, per Display-Manager wählbar)";
      displayManager = lib.mkOption {
        type = lib.types.enum ["greetd" "sddm"];
        default = "greetd";
        description = "Login-Manager für Plasma/Niri. greetd+tuigreet (leicht) oder sddm (KDE-Standard, beide Sessions wählbar).";
      };
    };
  };

  config = lib.mkIf config.lucy.plasma.enable (lib.mkMerge [
    {
      services.xserver.enable = true;
      services.desktopManager.plasma6.enable = true;

      programs.dconf.enable = true;
      services.gvfs.enable = true;
      # GNOME and Plasma otherwise provide conflicting mkDefault askpass paths.
      programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    }

    (lib.mkIf (config.lucy.plasma.displayManager == "sddm") {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };

      # Only one greeter; do not enable Niri against an explicit host choice.
      services.displayManager.gdm.enable = lib.mkForce false;
      services.greetd.enable = lib.mkForce false;
      services.displayManager.defaultSession =
        if config.programs.niri.enable
        then "niri"
        else "plasma";
    })
  ]);
}
