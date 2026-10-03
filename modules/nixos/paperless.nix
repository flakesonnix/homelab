{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.paperless;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [80];
    networking.firewall.interfaces."vm-documents" = {
      allowedTCPPorts = [80];
    };
    systemd.services.paperless = {
      description = "Paperless-ngx document management";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 paperless paperless - -"
    ];
  };
}
