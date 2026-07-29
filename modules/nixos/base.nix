{
  lib,
  config,
  pkgs,
  ...
}: {
  options = {
    lucy.base = {
      enable = lib.mkEnableOption "Base configuration shared across all hosts";
      isServer = lib.mkEnableOption "Server mode (no desktop apps)";
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

    lucy.topology = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Metadata for nix-topology rendering (icon, hardware.info, deviceType)";
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
        X11Forwarding = !config.lucy.base.isServer;
      };
    };

    security.sudo.enable = lib.mkDefault true;

    virtualisation.libvirtd = lib.mkIf (!config.lucy.base.isServer) {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
    };

    environment.systemPackages = with pkgs; [
      (lib.mkIf (!config.lucy.base.isServer) virt-manager)
      (lib.mkIf (!config.lucy.base.isServer) virt-viewer)
      (lib.mkIf (!config.lucy.base.isServer) gnome-tweaks)
      wl-clipboard
    ];

    users.users.lucy.extraGroups = lib.mkIf (!config.lucy.base.isServer) ["libvirtd"];

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [22 24800] ++ (lib.range 5555 5585);
      allowedUDPPorts = [5555 5585];
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
      hostKeys = ["/etc/secrets/initrd/ssh_host_ed25519_key"];
      authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
    };
    boot.initrd.availableKernelModules = ["r8169" "e1000e"];

    nix.settings.trusted-users = ["root" "lucy"];
    nix.settings.require-sigs = false;

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nix.optimise.automatic = true;

    services.openssh.settings.PermitRootLogin = "prohibit-password";

    security.run0-sudo-shim.enable = true;
    security.polkit.persistentAuthentication = lib.mkDefault true;

    boot.loader.efi.canTouchEfiVariables = true;

    fileSystems = lib.optionalAttrs (!config.lucy.base.isServer) {
      "/mnt/mireo/data" = {
        device = "10.8.0.1:/data";
        fsType = "nfs";
        options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=600"];
      };
    };

    systemd.tmpfiles.rules = lib.optionals (!config.lucy.base.isServer) [
      "L /home/lucy/data - - - - /mnt/mireo/data"
    ];
  };
}
