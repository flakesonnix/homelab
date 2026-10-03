{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.nextcloud;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.interfaces."vm-cloud" = {
      allowedTCPPorts = [443];
    };
    systemd.services.nextcloud = {
      description = "Nextcloud server";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 nextcloud nextcloud - -"
    ];
  };
}
