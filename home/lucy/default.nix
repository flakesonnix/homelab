{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./packages.nix
    # (import ../../modules/home/ssh.nix)
  ];

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    systemd = {
      enable = true;
    };
    settings = {
      main = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "network" "pulseaudio" "battery" "cpu" "memory" ];
      };

      "niri/workspaces" = {
        format = "{}";
        persistent-workspaces = {
          "*" = 5;
        };
      };

      "niri/window" = {
        max-length = 50;
      };

      clock = {
        format = "{:%a %d %b %H:%M}";
        interval = 1;
      };

      network = {
        format-wifi = "wifi {}%";
        format-ethernet = "eth";
        format-disconnected = "off";
        interval = 5;
      };

      pulseaudio = {
        format = "vol {}%";
        format-muted = "mute";
        on-click = "pavucontrol";
      };

      battery = {
        format = "{}%";
        format-charging = "chr {}%";
        format-plugged = "pwr {}%";
        states = {
          good = 60;
          warning = 30;
          critical = 15;
        };
      };

      cpu = {
        format = "cpu {}%";
        on-click = "alacritty -e htop";
        interval = 2;
      };

      memory = {
        format = "mem {}%";
        on-click = "alacritty -e htop";
        interval = 2;
      };
    };

    style = ''
      * {
        font-family: "JetBrains Mono", "Symbols Nerd Font", "monospace";
        font-size: 13px;
      }
      window#waybar {
        background: #1d2021;
        color: #ebdbb2;
      }
      #workspaces {
        padding: 0 8px;
      }
      #workspaces button {
        padding: 0 4px;
      }
      #workspaces button.active {
        color: #fb4934;
      }
      #clock, #battery, #cpu, #memory, #network, #pulseaudio, #tray {
        padding: 0 12px;
      }
      #battery.warning {
        color: #fabd2f;
      }
      #battery.critical {
        color: #fb4934;
      }
      #cpu.warning, #memory.warning {
        color: #fabd2f;
      }
    '';
  };

  home.packages = with pkgs; [
    jetbrains-mono
  ];

  stylix = {
    enable = true;
    base16Scheme = {
      scheme = "Custom";
      base00 = "1a1520";
      base01 = "2e2334";
      base02 = "52374f";
      base03 = "6c70a8";
      base04 = "7986a3";
      base05 = "a990af";
      base06 = "d8b3cf";
      base07 = "f8f2f7";
      base08 = "de99ac";
      base09 = "bf8c79";
      base0A = "778ad8";
      base0B = "a1a5e0";
      base0C = "b8d4e8";
      base0D = "96656a";
      base0E = "d8b3cf";
      base0F = "52374f";
    };
    targets.gnome.enable = false;
    targets.waybar.enable = true;
    targets.waybar.font = "monospace";
  };

  gtk = {
    gtk4.theme = null;
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;

  xdg.configFile."niri/config.kdl" = {
    source = pkgs.writeText "niri-config.kdl" ''
      input {
        keyboard {
          xkb {
            layout "us"
          }
        }
        touchpad {
          tap
          natural-scroll
        }
      }

      layout {
        gaps 16
      }

      prefer-no-csd

      binds {
        Mod+Shift+Slash {
          show-hotkey-overlay
        }
        Mod+T {
          spawn "alacritty"
        }
        Mod+D {
          spawn "fuzzel"
        }
        Mod+Q {
          close-window
        }
        Mod+Left {
          focus-column-left
        }
        Mod+Down {
          focus-window-down
        }
        Mod+Up {
          focus-window-up
        }
        Mod+Right {
          focus-column-right
        }
        Mod+H {
          focus-column-left
        }
        Mod+J {
          focus-window-down
        }
        Mod+K {
          focus-window-up
        }
        Mod+L {
          focus-column-right
        }
        Mod+Ctrl+Left {
          move-column-left
        }
        Mod+Ctrl+Down {
          move-window-down
        }
        Mod+Ctrl+Up {
          move-window-up
        }
        Mod+Ctrl+Right {
          move-column-right
        }
        Mod+Ctrl+H {
          move-column-left
        }
        Mod+Ctrl+J {
          move-window-down
        }
        Mod+Ctrl+K {
          move-window-up
        }
        Mod+Ctrl+L {
          move-column-right
        }
        Mod+Page_Down {
          focus-workspace-down
        }
        Mod+Page_Up {
          focus-workspace-up
        }
        Mod+U {
          focus-workspace-down
        }
        Mod+I {
          focus-workspace-up
        }
        Mod+1 {
          focus-workspace 1
        }
        Mod+2 {
          focus-workspace 2
        }
        Mod+3 {
          focus-workspace 3
        }
        Mod+4 {
          focus-workspace 4
        }
        Mod+5 {
          focus-workspace 5
        }
        Mod+6 {
          focus-workspace 6
        }
        Mod+7 {
          focus-workspace 7
        }
        Mod+8 {
          focus-workspace 8
        }
        Mod+9 {
          focus-workspace 9
        }
        Mod+Comma {
          consume-window-into-column
        }
        Mod+Period {
          expel-window-from-column
        }
        Mod+R {
          switch-preset-column-width
        }
        Mod+F {
          maximize-column
        }
        Mod+Shift+F {
          fullscreen-window
        }
        Mod+C {
          center-column
        }
        Print {
          screenshot
        }
        Mod+Shift+E {
          quit
        }
      }
    '';
  };

}
