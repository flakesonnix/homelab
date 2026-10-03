{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.syncthing;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [8384 22000];
    networking.firewall.interfaces."vm-sync" = {
      allowedTCPPorts = [8384 22000];
    };
    systemd.services.syncthing = {
      description = "Syncthing file synchronization";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 syncthing syncthing - -"
    ];
  };
}
