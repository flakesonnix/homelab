{
  lib,
  config,
  ...
}: {
  options = {
    lucy.secrets = {
      enable = lib.mkEnableOption "sops-nix secrets management";

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to host encrypted secrets file (yaml/json).";
      };

      ageKeyPath = lib.mkOption {
        type = lib.types.path;
        default = /etc/sops/age/keys.txt;
        description = "Path to age private key file";
      };
    };
  };

  config = let
    cfg = config.lucy.secrets;
  in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.sopsFile != null;
          message = "lucy.secrets.enable=true but lucy.secrets.sopsFile is null. Point it at your encrypted secrets file (e.g. hosts/<host>/secrets.yaml).";
        }
      ];

      sops = {
        defaultSopsFile = cfg.sopsFile;
        age.keyFile = cfg.ageKeyPath;
      };
    };
}
