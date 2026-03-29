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
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "network" "pulseaudio" "battery" "cpu" "memory" ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ];
          persistent-workspaces = {
            "*" = 5;
          };
        };

        "niri/window" = {
          max-length = 50;
        };

        clock = {
          format = "%A %d %B  %H:%M";
          format-alt = "{:%A, %d %B %Y}";
          tooltip-format = "<big>{:%Y}</big>\n<tt><calendar></calendar></tt>";
          interval = 1;
        };

        tray = {
          spacing = 10;
        };

        network = {
          format-wifi = "󰤨 {signalStrength}%";
          format-ethernet = "󰈀 ETH";
          format-disconnected = "󰤭";
          format-alt = "{ifname}: {ipaddr}";
          interval = 5;
        };

        pulseaudio = {
          format = "󰕾 {volume}%";
          format-muted = "󰝟";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = "pavucontrol";
        };

        battery = {
          states = {
            good = 60;
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        cpu = {
          format = "󰻠 {usage}%";
          on-click = "alacritty -e htop";
          interval = 2;
          states = {
            high = 85;
            medium = 70;
          };
        };

        memory = {
          format = "󰍭 {used:0.1f}GiB / {total:0.1f}GiB";
          on-click = "alacritty -e htop";
          interval = 2;
        };
      }
    ];
  };

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    targets.gnome.enable = false;
    targets.waybar.enable = true;
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

      spawn-at-startup "waybar"

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
