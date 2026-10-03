{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.hydra;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [443];
    networking.firewall.interfaces."vm-devops" = {
      allowedTCPPorts = [443];
    };
    systemd.services.hydra = {
      description = "Hydra CI build farm";
      wantedBy = ["multi-user.target"];
      after = ["postgresql.service"];
      serviceConfig = {Type = "simple";};
    };
    systemd.services.hydra-secrets-setup = {
      description = "Stage Hydra secrets from virtiofs share";
      before = ["hydra.service"];
      requiredBy = ["hydra.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /run/secrets/database /run/secrets/devops
        find /run/secrets/devops -type f -print0 | while IFS= read -r -d "" f; do
          install -D -o hydra -g hydra -m0400 "$f" "/run/secrets/devops/$(basename "$f")"
        done
      '';
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 hydra hydra - -"
    ];
  };
}
