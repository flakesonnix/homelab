{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.ntfy;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.interfaces."vm-communication" = {
      allowedTCPPorts = [443];
    };
    systemd.services.ntfy = {
      description = "ntfy notification server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ntfy}/bin/ntfy serve";
      };
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ntfy ntfy - -"
    ];
  };
}
