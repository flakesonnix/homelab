{
  lib,
  config,
  ...
}: let
  cfg = config.lucy.sunshine;
in {
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
  };
}
