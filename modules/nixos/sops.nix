{
  lib,
  config,
  ...
}: {
  options = {
    lucy.secrets = {
      enable = lib.mkEnableOption "sops-nix secrets management";
      defaultSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Default sops file for host secrets.";
      };
      ageKeyPath = lib.mkOption {
        type = lib.types.path;
        default = /etc/sops/age/keys.txt;
        description = "Path to age private key file";
      };
    };
  };

  config = lib.mkIf config.lucy.secrets.enable {
    sops =
      {
        age.keyFile = config.lucy.secrets.ageKeyPath;
        secrets = {
          pppoe-password = {
            sopsFile = ./secrets.yaml;
            format = "binary";
          };
          luks-key = {
            sopsFile = ./secrets.yaml;
            format = "binary";
          };
        };
      }
      // lib.optionalAttrs (config.lucy.secrets.defaultSopsFile != null) {
        inherit (config.lucy.secrets) defaultSopsFile;
      };
  };
}
