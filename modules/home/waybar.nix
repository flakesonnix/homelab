{ lib, config, pkgs, ... }:

{
  options.lucy.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.lucy.waybar.enable {
    home.packages = [ pkgs.siji ];
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "top";
          position = "top";
          height = 40;
          margin-top = 10;
          margin-left = 14;
          margin-right = 14;
          modules-left = [ "niri/workspaces" ];
          modules-center = [ "clock" "idle_inhibitor" ];
          modules-right = [ "network" "pulseaudio" "battery" "cpu" "memory" "temperature" "disk" "custom/power" ];

          "niri/workspaces" = {
            format = "{index}";
            persistent-workspaces = { "*" = 5; };
          };

          clock = { format = "{:%H:%M}"; format-alt = "{:%d.%m.%Y}"; interval = 1; };
          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = "☕";
              deactivated = "󰅶";
            };
          };
          network = { format-wifi = "  {signalStrength}%"; format-ethernet = ""; format-disconnected = ""; interval = 5; on-click = "alacritty -e nmtui"; };
          pulseaudio = { format = "  {volume}%"; format-muted = ""; on-click = "pavucontrol"; };
          battery = { states = { good = 60; warning = 30; critical = 15; }; format = "{icon} {capacity}%"; format-icons = [ "" "" "" "" "" ]; };
          cpu = { format = "{usage}%"; on-click = "alacritty -e htop"; interval = 2; };
          memory = { format = "{used:0.1f}GiB"; on-click = "alacritty -e htop"; interval = 2; };
          temperature = { thermal-zone = 2; critical-threshold = 80; format = " {temperatureC}°C"; };
          disk = { format = " {used}/{total}"; tooltip = true; };
          "custom/power" = { format = "⏻"; on-click = "wlogout"; tooltip = false; };
        }
        {
          name = "dock";
          layer = "top";
          position = "bottom";
          exclusive = false;
          height = 56;
          margin-bottom = 18;
          modules-left = [ ];
          modules-center = [ "custom/launcher" "custom/firefox" "custom/files" "custom/terminal" "custom/vesktop" "custom/thunderbird" ];
          modules-right = [ ];

          "custom/launcher" = { format = "󰣇"; on-click = "fuzzel"; tooltip = false; };
          "custom/firefox" = { format = "󰈹"; on-click = "firefox"; tooltip = false; };
          "custom/files" = { format = "󰉋"; on-click = "nautilus"; tooltip = false; };
          "custom/terminal" = { format = ""; on-click = "alacritty"; tooltip = false; };
          "custom/vesktop" = { format = "󰙯"; on-click = "vesktop"; tooltip = false; };
          "custom/thunderbird" = { format = "󰇮"; on-click = "thunderbird"; tooltip = false; };
        }
      ];

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace;
          font-size: 13px;
          min-height: 0;
        }

        window#waybar {
          background: transparent;
          color: #ffb6c1;
        }

        window#waybar.dock {
          color: #f0d0f5;
        }

        .modules-left,
        .modules-center,
        .modules-right {
          margin: 0;
          background: linear-gradient(180deg, rgba(58, 51, 74, 0.74), rgba(24, 20, 31, 0.68));
          border: 1px solid rgba(255, 255, 255, 0.16);
          border-radius: 18px;
          box-shadow: 0 14px 36px rgba(10, 8, 15, 0.26), inset 0 1px 0 rgba(255, 255, 255, 0.1);
          padding: 4px 6px;
        }

        window#waybar.dock .modules-center {
          padding: 8px 10px;
          border-radius: 22px;
          background: linear-gradient(180deg, rgba(64, 58, 80, 0.76), rgba(24, 20, 31, 0.72));
          box-shadow: 0 18px 42px rgba(10, 8, 15, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.12);
        }

        #workspaces,
        #clock,
        #idle_inhibitor,
        #network,
        #pulseaudio,
        #battery,
        #cpu,
        #memory,
        #temperature,
        #disk,
        #custom-power {
          background: transparent;
          border: none;
          border-radius: 14px;
          margin: 0 2px;
          padding: 0 12px;
          box-shadow: none;
        }

        window#waybar.dock #custom-launcher,
        window#waybar.dock #custom-firefox,
        window#waybar.dock #custom-files,
        window#waybar.dock #custom-terminal,
        window#waybar.dock #custom-vesktop,
        window#waybar.dock #custom-thunderbird {
          min-width: 28px;
          padding: 0 14px;
          font-size: 19px;
          border-radius: 14px;
          transition: all 180ms ease;
        }

        window#waybar.dock #custom-launcher:hover,
        window#waybar.dock #custom-firefox:hover,
        window#waybar.dock #custom-files:hover,
        window#waybar.dock #custom-terminal:hover,
        window#waybar.dock #custom-vesktop:hover,
        window#waybar.dock #custom-thunderbird:hover {
          background: rgba(255, 255, 255, 0.08);
          color: #ffffff;
        }

        window#waybar.dock #custom-launcher {
          color: #ffb6c1;
          margin-right: 6px;
        }

        #workspaces {
          margin-left: 0;
          padding: 0 4px;
        }

        #workspaces button {
          color: #dda0dd;
          padding: 4px 10px;
          margin: 2px;
          border-radius: 12px;
        }

        #workspaces button.active {
          color: #fff;
          background: linear-gradient(135deg, #ff69b4, #c678dd);
          box-shadow: 0 8px 18px rgba(198, 120, 221, 0.28), inset 0 0 0 1px rgba(255, 255, 255, 0.08);
        }

        #workspaces button.urgent {
          background: linear-gradient(135deg, #ff69b4, #ff1493);
        }

        #clock {
          color: #ba55d3;
          font-weight: bold;
          padding: 0 18px;
          margin-right: 0;
        }

        #idle_inhibitor {
          color: #f1fa8c;
          margin-left: 0;
          padding-left: 10px;
        }

        #battery { color: #ff69b4; }
        #battery.charging { color: #50fa7b; }
        #battery.warning { color: #ffb86c; }
        #battery.critical { color: #ff5555; animation: blink 1s infinite; }

        #cpu, #memory { color: #c6a7ff; }
        #cpu.warning, #memory.warning { color: #ffb86c; }
        #cpu.critical, #memory.critical { color: #ff5555; }

        #temperature { color: #8be9fd; }
        #temperature.critical { color: #ff5555; }

        #disk { color: #bd93f9; }

        #custom-power {
          color: #ff79c6;
          min-width: 22px;
          padding: 0 12px;
        }

        #custom-power:hover {
          color: #ff5555;
          background: rgba(255, 105, 180, 0.14);
        }
        #network { color: #ba55d3; }
        #network.disconnected { color: #ff5555; }
        #pulseaudio { color: #ff69b4; }
        #pulseaudio.muted { color: #817695; }

        tooltip {
          background: rgba(42, 36, 54, 0.94);
          color: #ffb6c1;
          border: 1px solid rgba(255, 182, 193, 0.32);
          border-radius: 12px;
          padding: 8px 12px;
        }

        tooltip label { color: #dda0dd; }
      '';
    };
  };
}
