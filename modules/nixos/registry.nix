{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.registry;
in {
  config = lib.mkIf cfg.enable {
    services.dockerRegistry.enable = true;
    networking.firewall.allowedTCPPorts = [5000];
    networking.firewall.interfaces."vm-artifacts" = {
      allowedTCPPorts = [5000];
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 registry registry - -"
    ];
  };
}
