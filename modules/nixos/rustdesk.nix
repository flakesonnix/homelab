{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.rustdesk;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [21115 21116 21118 21119 21121 21122 21123 21124];
    networking.firewall.interfaces."vm-remote" = {
      allowedTCPPorts = [21115 21116 21118 21119 21121 21122 21123 21124];
    };
    systemd.services.rustdesk-hbbs = {
      description = "RustDesk Signal Hub Server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.rustdesk-hbbr = {
      description = "RustDesk Relay Server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 rustdesk rustdesk - -"
    ];
  };
}
