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
    substituters = lib.mkBefore ["http://omen:5000"];
  };
  nixpkgs.config.allowUnfree = true;

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
    windowManager.openbox.enable = true;
    desktopManager = {
      xterm.enable = false;
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

  environment.systemPackages = with pkgs; [
    tint2
    feh
    lxappearance
    obconf
  ];

  environment.etc."xdg/openbox/rc.xml".text = ''
    <?xml version="1.0"?>
    <openbox_config>
      <theme>
        <name>Clearlooks</name>
        <titleLayout>NLIMC</titleLayout>
        <keepBorder>yes</keepBorder>
        <animateIconify>no</animateIconify>
        <font place="ActiveWindow">
          <name>sans-serif</name>
          <size>9</size>
        </font>
        <font place="InactiveWindow">
          <name>sans-serif</name>
          <size>9</size>
        </font>
      </theme>
      <desktops>
        <number>1</number>
      </desktops>
      <resistance>
        <edge>10</edge>
      </resistance>
      <menu>
        <hideDelay>200</hideDelay>
        <showDelay>0</showDelay>
      </menu>
      <applications>
        <application class="*">
          <decor>yes</decor>
        </application>
      </applications>
    </openbox_config>
  '';

  environment.etc."xdg/tint2/tint2rc".text = ''
    # Panel
    panel_monitor = all
    panel_position = bottom center horizontal
    panel_size = 100% 30
    panel_margin = 0 0 0 0
    panel_padding = 4 4 4 4
    panel_background_id = 0

    # Clock
    clock_format = %H:%M
    clock_appearance = 0
    clock_tooltip = %A %d %B

    # Taskbar
    taskbar_name = 1
    taskbar_hide_if_empty = 1
    taskbar_name_background_id = 0

    # System tray
    systray = 1
    systray_padding = 4 2 4 2
  '';

  services.xserver.desktopManager.session = [
    {
      name = "openbox";
      start = ''
        ${lib.getExe pkgs.xsetroot} -solid "#2e3440" &
        ${pkgs.openbox}/bin/openbox --config-file /etc/xdg/openbox/rc.xml &
        ${pkgs.tint2}/bin/tint2 -c /etc/xdg/tint2/tint2rc &
        wait
      '';
    }
  ];

  hq.deskflow = {
    enable = true;
    role = "client";
    serverAddress = "omen";
  };

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
