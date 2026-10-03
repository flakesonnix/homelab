{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.immich;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.interfaces."vm-media" = {
      allowedTCPPorts = [443];
    };
    systemd.services.immich = {
      description = "Immich photo management";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 immich immich - -"
    ];
  };
}
