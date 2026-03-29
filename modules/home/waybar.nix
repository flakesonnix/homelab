{ lib, config, pkgs, ... }:

{
  options.lucy.waybar = {
    enable = lib.mkEnableOption "Waybar status bar";
  };

  config = lib.mkIf config.lucy.waybar.enable {
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
            time = {
              local = {
                format = "%H:%M";
              };
            };
            date = {
              format = "%d.%m.%Y";
            };
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
            tooltip-format = "{ifname} ({gwaddr})";
          };

          pulseaudio = {
            format = "󰕾 {volume}%";
            format-muted = "󰝟";
            format-icons = {
              default = [ "󰕿" "󰖀" "󰕾" ];
            };
            on-click = "pavucontrol";
            tooltip-format = "{desc}, {volume}%";
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
            states = {
              low = 20;
              high = 90;
            };
            tooltip-format = "RAM: {used:0.1f}GiB / {total:0.1f}GiB\nSwap: {swapUsed:0.1f}GiB / {swapTotal:0.1f}GiB";
          };
        }
      ];

      style = lib.mkDefault null;
    };
  };
}
