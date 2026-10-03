{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.reverseProxy;
in {
  config = lib.mkIf cfg.enable {
    services.caddy.enable = true;
    networking.firewall.allowedTCPPorts = [80 443];
    systemd.tmpfiles.rules = [
      "d /var/lib/caddy 0750 caddy caddy - -"
    ];
  };
}
