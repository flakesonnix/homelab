{ lib, config, pkgs, ... }:

{
  options.lucy.waybar = { home.packages = [ pkgs.siji pkgs.nerd-fonts.jetbrains-mono ];
    enable = lib.mkEnableOption "Waybar status bar";
  };

  config = lib.mkIf config.lucy.waybar.enable {
    home.packages = [ pkgs.siji pkgs.nerd-fonts.jetbrains-mono ];
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "top";
          position = "top";
          height = 32;
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [ "tray" "network" "pulseaudio" "battery" "cpu" "memory" ];

          "hyprland/workspaces" = {
            format = "{icon}";
            format-icons = {
              "1" = "󰎙";
              "2" = "󰎠";
              "3" = "󰎢";
              "4" = "󰎤";
              "5" = "󰎥";
              "6" = "󰎦";
              "7" = "󰎨";
              "8" = "󰎪";
              "9" = "󰎬";
              "10" = "󰎭";
            };
            persistent-workspaces = {
              "*" = 5;
            };
          };

          clock = {
            format = "{:%H:%M}";
            format-alt = "{:%d.%m.%Y}";
            interval = 1;
          };

          tray = {
            spacing = 8;
          };

          network = {
            format-wifi = "wifi {signal}%";
            format-ethernet = "LAN";
            format-disconnected = "offline";
            format-adapter = "{ifname}";
            interval = 5;
            tooltip-format = "type: {ifname}";
          };

          pulseaudio = {
            format = "{volume}%";
            format-muted = "muted";
            on-click = "pavucontrol";
          };

          battery = {
            states = {
              good = 60;
              warning = 30;
              critical = 15;
            };
            format = "{capacity}%";
            format-charging = "󰂞 {capacity}%";
            format-plugged = "󰂄";
            format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          };

          cpu = {
            format = "{usage}%";
            on-click = "alacritty -e htop";
            interval = 2;
          };

          memory = {
            format = "{used:0.1f}GiB";
            on-click = "alacritty -e htop";
            interval = 2;
          };
        }
      ];

      style = ''
        * {
          font-family: "JetBrains Mono", monospace;
          font-size: 13px;
        }
        window#waybar {
          background: linear-gradient(180deg, #2a1f35 0%, #1a1423 100%);
          color: #ffb6c1;
          border-bottom: 3px solid #ff69b4;
        }
        #workspaces {
          margin-left: 8px;
        }
        #workspaces button {
          color: #dda0dd;
          padding: 4px 10px;
          margin: 2px;
        }
        #workspaces button.active {
          color: #fff;
          background: linear-gradient(135deg, #ff69b4, #c678dd);
          border-radius: 12px;
          box-shadow: 0 2px 8px rgba(255, 105, 180, 0.4);
        }
        #workspaces button.urgent {
          background: linear-gradient(135deg, #ff69b4, #ff1493);
          border-radius: 12px;
        }
        #clock {
          color: #ba55d3;
          font-weight: bold;
        }
        #battery {
          color: #ff69b4;
        }
        #battery.charging {
          color: #50fa7b;
        }
        #battery.warning {
          color: #ffb86c;
        }
        #battery.critical {
          color: #ff5555;
          animation: blink 1s infinite;
        }
        #cpu, #memory {
          color: #c6a7ff;
        }
        #cpu.warning, #memory.warning {
          color: #ffb86c;
        }
        #cpu.critical, #memory.critical {
          color: #ff5555;
        }
        #tray {
          color: #dda0dd;
        }
        #tray > .passive {
          color: #817695;
        }
        #network {
          color: #ba55d3;
        }
        #network.disconnected {
          color: #ff5555;
        }
        #pulseaudio {
          color: #ff69b4;
        }
        #pulseaudio.muted {
          color: #817695;
        }
        tooltip {
          background: #2a2436;
          color: #ffb6c1;
          border: 2px solid #ff69b4;
          border-radius: 12px;
          padding: 8px 12px;
        }
        tooltip label {
          color: #dda0dd;
        }
      '';
    };
  };
}
