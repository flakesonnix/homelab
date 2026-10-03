{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.woodpecker;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [80];
    networking.firewall.interfaces."vm-devops" = {
      allowedTCPPorts = [80];
    };
    systemd.services.woodpecker = {
      description = "Woodpecker CI server";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.woodpecker-secrets-setup = {
      description = "Stage Woodpecker secrets from virtiofs share";
      before = ["woodpecker.service"];
      requiredBy = ["woodpecker.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /run/secrets/database /run/secrets/devops
        find /run/secrets/devops -type f -print0 | while IFS= read -r -d "" f; do
          install -D -o woodpecker -g woodpecker -m0400 "$f" "/run/secrets/devops/$(basename "$f")"
        done
      '';
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 woodpecker woodpecker - -"
    ];
  };
}
