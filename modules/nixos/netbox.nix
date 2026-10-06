{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.netbox;
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
    systemd.services.netbox = {
      description = "NetBox network inventory";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.netbox-reconcile = {
      description = "Reconcile NetBox inventory from Nix data (idempotent)";
      after = ["netbox.service"];
      requires = ["netbox.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment.NETBOX_URL = "https://netbox.${domain}";
      # Per-VM secrets dir (least privilege); key: management/netbox-api-token.
      environment.NETBOX_TOKEN_FILE = "/run/secrets/management/netbox-api-token";
      path = with pkgs; [curl jq];
      script = ''
        set -eu
        token=$(cat "$NETBOX_TOKEN_FILE")
        devices='${builtins.toJSON (import ../../data/network/devices.nix {inherit lib;}).devices}'
        echo "$devices" | jq -c '.[]' | while read -r device; do
          name=$(jq -r '.name' <<<"$device")
          curl -sf -X PUT "https://netbox.${domain}/api/dcim/devices/" \
            -H "Authorization: Token $token" \
            -H "Content-Type: application/json" \
            -d "$device" || \
          curl -sf -X POST "https://netbox.${domain}/api/dcim/devices/" \
            -H "Authorization: Token $token" \
            -H "Content-Type: application/json" \
            -d "$device" || true
        done
      '';
    };
    systemd.timers.netbox-reconcile = {
      description = "Daily NetBox inventory convergence";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 netbox netbox - -"
    ];
  };
}
