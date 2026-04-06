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
        description = "SSH public key for user authentication";
      };
      sshKeyComment = lib.mkOption {
        type = lib.types.str;
        default = "lucy@dotfiles";
        description = "SSH key comment";
      };
      initrdSshPort = lib.mkOption {
        type = lib.types.int;
        default = 2222;
        description = "Port for SSH access during initrd unlock";
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

    security.sudo = {
      enable = true;
      extraRules = [
        {
          users = [ "lucy" ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };

    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
    };

    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      gnome-tweaks
    ];

    users.users.lucy.extraGroups = [ "libvirtd" ];

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 24800 ];
    };

    users.users.lucy.openssh.authorizedKeys.keys = [
      "${config.lucy.base.sshKey} ${config.lucy.base.sshKeyComment}"
    ];

    users.users.root.openssh.authorizedKeys.keys = [
      "${config.lucy.base.sshKey} ${config.lucy.base.sshKeyComment}"
    ];

    boot.initrd.network.ssh = {
      enable = true;
      port = config.lucy.base.initrdSshPort;
      hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
    };
    boot.initrd.availableKernelModules = [ "r8169" "e1000e" ];

    sops = {
      defaultSopsFile = ./secrets.yaml;
      age.keyFile = /etc/sops/age/keys.txt;
    };
  };
}
