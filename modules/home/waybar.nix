{ lib, config, pkgs, ... }:

{
  options.lucy.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.lucy.waybar.enable {
    home.packages = [ pkgs.siji ];
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [{
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
        "custom/power" = { format = "⏻"; on-click = "loginctl kill-user $USER"; tooltip = false; };
      }];

      style = ''
        * { font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace; font-size: 13px; }
        window#waybar { background: linear-gradient(180deg, #2a1f35 0%, #1a1423 100%); color: #ffb6c1; border: 2px solid #ff69b4; border-radius: 16px; }
        #workspaces { margin-left: 8px; }
        #workspaces button { color: #dda0dd; padding: 4px 10px; margin: 2px; }
        #workspaces button.active { color: #fff; background: linear-gradient(135deg, #ff69b4, #c678dd); border-radius: 12px; box-shadow: 0 2px 8px rgba(255,105,180,0.4); }
        #workspaces button.urgent { background: linear-gradient(135deg, #ff69b4, #ff1493); border-radius: 12px; }
        #clock { color: #ba55d3; font-weight: bold; }
        #battery { color: #ff69b4; } #battery.charging { color: #50fa7b; } #battery.warning { color: #ffb86c; } #battery.critical { color: #ff5555; animation: blink 1s infinite; }
        #cpu, #memory { color: #c6a7ff; } #cpu.warning, #memory.warning { color: #ffb86c; } #cpu.critical, #memory.critical { color: #ff5555; }
        #temperature { color: #8be9fd; } #temperature.critical { color: #ff5555; }
        #disk { color: #bd93f9; }
        #custom-power { color: #ff79c6; min-width: 22px; padding: 0 6px; } #custom-power:hover { color: #ff5555; }
        #idle_inhibitor { color: #f1fa8c; }
        #network { color: #ba55d3; } #network.disconnected { color: #ff5555; }
        #pulseaudio { color: #ff69b4; } #pulseaudio.muted { color: #817695; }
        tooltip { background: #2a2436; color: #ffb6c1; border: 2px solid #ff69b4; border-radius: 12px; padding: 8px 12px; }
        tooltip label { color: #dda0dd; }
      '';
    };
  };
}
