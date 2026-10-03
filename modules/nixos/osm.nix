{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.osm;
in {
  config = lib.mkIf cfg.enable {
    services.postgresql.enable = true;
    networking.firewall.allowedTCPPorts = [80 443];
    systemd.services.osm = {
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
    };
    systemd.tmpfiles.rules = [
      "d /data/osm 0750 osm osm - -"
    ];
  };
}
