{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lucy.waydroid;
  package = config.virtualisation.waydroid.package;
in
{
  options.lucy.waydroid = {
    enable = lib.mkEnableOption "Waydroid Android container";
    gapps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Initialize with Google Apps (GAPPS) image";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.waydroid = {
      enable = true;
      # Modern kernels can omit legacy ip_tables even with an iptables-nft firewall.
      package = pkgs.waydroid-nftables;
    };

    systemd.services.waydroid-gapps-init = lib.mkIf cfg.gapps {
      description = "Waydroid GApps image initialisation";
      after = [ "network-online.target" ];
      wants = [
        "network-online.target"
        "waydroid-container.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [
        package
        pkgs.curl
        pkgs.xz
      ];
      unitConfig.ConditionPathExists = "!/var/lib/waydroid/images/system.img";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${package}/bin/waydroid init -s GAPPS";
        TimeoutStartSec = "infinity";
      };
    };
  };
}
