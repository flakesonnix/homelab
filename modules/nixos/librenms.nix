{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.librenms;
  domain =
    if config.networking.domain == null
    then "home.arpa"
    else config.networking.domain;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.interfaces."vm-management" = {
      allowedTCPPorts = [443];
    };
    systemd.services.librenms = {
      description = "LibreNMS network monitoring";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.librenms-reconcile = {
      description = "Reconcile LibreNMS devices from Nix data (idempotent)";
      after = ["librenms.service"];
      requires = ["librenms.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment.LIBRENMS_API_KEY_FILE = "/run/secrets/management/librenms-api-key";
      path = with pkgs; [curl jq];
      script = ''
        set -eu
        key=$(cat "$LIBRENMS_API_KEY_FILE")
        devices='${builtins.toJSON (import ../../data/network/devices.nix {inherit lib;}).devices}'
        echo "$devices" | jq -c '.[]' | while read -r device; do
          hostname=$(jq -r '.name' <<<"$device")
          curl -sf -X POST "https://librenms.${domain}/api/v0/devices" \
            -H "X-Auth-Token: $key" \
            -H "Content-Type: application/json" \
            -d "{\"hostname\": \"$hostname\"}" || true
        done
      '';
    };
    systemd.timers.librenms-reconcile = {
      description = "Daily LibreNMS device convergence";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
    systemd.services.net-snmp = {
      description = "SNMP daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {Type = "simple";};
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 librenms librenms - -"
    ];
  };
}
