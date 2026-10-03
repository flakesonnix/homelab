{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.matrix;
in {
  config = lib.mkIf cfg.enable {
    services.matrix-synapse.enable = true;
    networking.firewall.allowedTCPPorts = [443 8448];
    networking.firewall.interfaces."vm-communication" = {
      allowedTCPPorts = [443 8448];
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 matrix matrix - -"
    ];
  };
}
