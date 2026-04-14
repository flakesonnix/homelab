{ lib, config, ... }:

{
  options = {
    lucy.gnome = {
      enable = lib.mkEnableOption "GNOME desktop configuration";
      wayland = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Wayland for GDM";
      };
    };
  };

  config = lib.mkIf config.lucy.gnome.enable {
    services.xserver.enable = true;
    services.displayManager.gdm = {
      enable = true;
      wayland = config.lucy.gnome.wayland;
    };
    services.desktopManager.gnome.enable = true;
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    services.printing.enable = true;
    programs.firefox.enable = true;
    programs.dconf.enable = true;
  };
}