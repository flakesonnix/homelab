{
  lib,
  config,
  ...
}:
let
  cfg = config.lucy.sunshine;
in
{
  options.lucy.sunshine = {
    enable = lib.mkEnableOption "Sunshine game-stream host (Moonlight)";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Sunshine ports in the firewall.";
    };

    capSysAdmin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Grant CAP_SYS_ADMIN for DRM/KMS screen capture (Wayland).";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Sunshine automatically with the graphical session.";
    };
  };

  # NOTE: settings bewusst leer lassen, damit Pairing/Config weiter per
  # Web-UI (https://localhost:47984) möglich bleibt. Sobald `settings` oder
  # `applications` gesetzt sind, rendert das Upstream-Modul eine Config-Datei
  # und sperrt die Web-UI.
  config = lib.mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      inherit (cfg) openFirewall capSysAdmin autoStart;
    };

    services.avahi = {
      # The pinned upstream Sunshine module still sets deprecated defaults.
      # Clear those aliases, preserving the same discovery configuration.
      publish = {
        enable = null;
        userServices = null;
      };
      settings.publish = {
        disable-publishing = lib.mkDefault false;
        disable-user-service-publishing = lib.mkDefault false;
        publish-addresses = lib.mkDefault true;
      };
    };
  };
}
