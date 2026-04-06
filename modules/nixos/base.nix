{ lib, config, pkgs, ... }:

{
  options = {
    lucy.base = {
      enable = lib.mkEnableOption "Base configuration shared across all hosts";
      timezone = lib.mkOption {
        type = lib.types.str;
        default = "Europe/Berlin";
        description = "Timezone";
      };
      locale = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
        description = "Default locale";
      };
      sshKey = lib.mkOption {
        type = lib.types.str;
        description = "SSH public key";
      };
      sshKeyComment = lib.mkOption {
        type = lib.types.str;
        default = "lucy@dotfiles";
        description = "SSH key comment";
      };
    };
  };

  config = lib.mkIf config.lucy.base.enable {
    time.timeZone = config.lucy.base.timezone;

    i18n.defaultLocale = config.lucy.base.locale;

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        X11Forwarding = true;
      };
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 24800 ];
    };

    ssh-keys = {
      publicKey = config.lucy.base.sshKey;
      comment = config.lucy.base.sshKeyComment;
    };

    sops = {
      defaultSopsFile = ./secrets.yaml;
      age = {
        generateKey = true;
      };
      secrets = { };
    };
  };
}
