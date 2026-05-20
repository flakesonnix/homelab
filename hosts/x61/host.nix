{
  lib,
  pkgs,
  ...
}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
  grafanaUrl = "http://10.8.0.2:3000/d/mireo-router/mireo-router?kiosk";
in {
  imports = [
    ../../modules/nixos/pipebert.nix
  ];

  networking.hostName = "x61";
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "lucy"];
  };
  nixpkgs.config.allowUnfree = true;

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
    displayManager = {
      lightdm.enable = true;
      session = [
        {
          manage = "window";
          name = "kiosk";
          start = ''
            ${lib.getExe pkgs.xset} s off
            ${lib.getExe pkgs.xset} -dpms
            ${lib.getExe pkgs.xset} s noblank

            exec ${lib.getExe pkgs.firefox} --kiosk --private-window ${lib.escapeShellArg grafanaUrl}
          '';
        }
      ];
    };
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lucy";
  services.displayManager.defaultSession = "none+kiosk";

  programs.firefox.enable = true;
  programs.dconf.enable = true;

  users.users = {
    lucy = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager"];
      openssh.authorizedKeys.keys = [keys.lucy.servers];
    };
    root.openssh.authorizedKeys.keys = [keys.lucy.servers];
  };

  lucy.pipebert = {
    enable = true;
    user = "lucy";
    openFirewall = true;
  };

  fileSystems."/mnt/mireo/data" = {
    device = "10.8.0.1:/data";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=600"];
  };

  system.stateVersion = "25.11";
}
