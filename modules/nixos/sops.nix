{ lib, config, ... }:

{
  options = {
    lucy.secrets = {
      enable = lib.mkEnableOption "sops-nix secrets management";
      ageKeyPath = lib.mkOption {
        type = lib.types.path;
        default = /etc/sops/age/keys.txt;
        description = "Path to age private key file";
      };
    };
  };

  config = lib.mkIf config.lucy.secrets.enable {
    sops = {
      defaultSopsFile = ./secrets.yaml;
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
    };
  };
}
