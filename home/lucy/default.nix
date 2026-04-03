{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/packages.nix
    ./programs/easyeffects
    ./programs/htop.nix
    ./programs/btop.nix
    ../../modules/home/stylix.nix
  ];

  lucy.shell.enable = true;
  lucy.git.enable = true;
  lucy.editor.enable = true;
  lucy.easyeffects.enable = true;
  lucy.htop.enable = true;
  lucy.btop.enable = true;
  lucy.stylix.enable = true;
  lucy.programs.jetbrains-mono = true;
  lucy.programs.wpaperd = true;
  lucy.programs.comma = true;

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "p50" = {
        host = "192.168.178.31";
        user = "lucy";
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    };
  };

  services.flatpak = {
    enable = true;
    packages = [
      "com.teamspeak.TeamSpeak"
    ];
  };

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "dash-to-dock@micxgx.gmail.com" ];
    };
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "LEFT";
      show-apps-at-top = true;
      extend-height = false;
      dash-max-icon-size = 48;
    };
  };

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "wlr/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "battery" "cpu" "memory" ];
        "wlr/workspaces" = {
          format = "{}";
        };
        clock = {
          format = "{:%H:%M}";
          interval = 1;
        };
        cpu = {
          format = "{}%";
          interval = 2;
        };
        memory = {
          format = "{}%";
          interval = 2;
        };
        battery = {
          format = "{}%";
          interval = 60;
        };
      }
    ];
    style = ''
      * {
        font-family: monospace;
        font-size: 12px;
      }
      window#waybar {
        background: #1a1520;
        color: #a990af;
      }
    '';
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
