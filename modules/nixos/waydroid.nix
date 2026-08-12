{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.waydroid;
in {
  options.lucy.waydroid = {
    enable = lib.mkEnableOption "Waydroid Android container";
    gapps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Initialize with Google Apps (GAPPS) image";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.waydroid.enable = true;

    environment.systemPackages = [
      pkgs.waydroid
    ];

    systemd.services.waydroid-gapps-init = lib.mkIf cfg.gapps {
      description = "Waydroid GApps image initialisation";
      after = ["network-online.target"];
      wants = ["network-online.target" "waydroid-container.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.waydroid pkgs.curl pkgs.xz];
      unitConfig.ConditionPathExists = "!/var/lib/waydroid/images/system.img";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.waydroid}/bin/waydroid init -s GAPPS";
        TimeoutStartSec = "infinity";
      };
    };
  };
}
