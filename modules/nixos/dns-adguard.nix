{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.dns;
in {
  config = lib.mkIf cfg.enable {
    services.adguardhome.enable = true;
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.allowedUDPPorts = [53];
    systemd.tmpfiles.rules = [
      "d /var/lib/adguardhome 0750 adguardhome adguardhome - -"
    ];
  };
}
