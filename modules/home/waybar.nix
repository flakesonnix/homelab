{
  lib,
  config,
  pkgs,
  ...
}: let
  projectLib = import ../../lib;
  colors = config.lib.stylix.colors.withHashtag;
  waybarFramework = projectLib.framework.waybar;
  renderCss = projectLib.render.css.renderSheet;

  waybarStyle = renderCss [
    (waybarFramework.rule "*" {
      font_family = ["Inter" "Hack Nerd Font" "sans-serif"];
      font_size = "14px";
      min_height = "0";
    })
    (waybarFramework.rule "window#waybar" {
      background = "linear-gradient(90deg, ${colors.base00}, ${colors.base01}, ${colors.base02})";
      color = colors.base07;
      border = "1px solid ${colors.base03}";
      border_radius = "18px";
      box_shadow = "0 14px 34px ${colors.base00}";
    })
    (waybarFramework.rule "window#waybar.dock" {
      background = "linear-gradient(90deg, ${colors.base00}, ${colors.base01}, ${colors.base02})";
      color = colors.base07;
      border = "1px solid ${colors.base03}";
      border_radius = "18px";
      box_shadow = "0 14px 34px ${colors.base00}";
    })
    (waybarFramework.rule "#workspaces" {
      margin_left = "0";
      padding = "0 6px";
    })
    (waybarFramework.rule "#workspaces button" {
      color = colors.base05;
      padding = "4px 12px";
      margin = "3px 2px";
      border_radius = "12px";
      border = "1px solid ${colors.base01}";
      transition = "all 150ms ease";
    })
    (waybarFramework.rule "#workspaces button:hover" {
      color = colors.base07;
      background = colors.base01;
      border = "1px solid ${colors.base03}";
    })
    (waybarFramework.rule "#workspaces button.active" {
      color = colors.base07;
      background = "linear-gradient(90deg, ${colors.base0D}, ${colors.base0C})";
      border = "1px solid ${colors.base06}";
      box_shadow = "0 6px 18px ${colors.base01}";
    })
    (waybarFramework.rule "#workspaces button.urgent" {
      background = colors.base08;
      color = colors.base07;
    })
    (waybarFramework.rule "#clock" {
      color = colors.base07;
      font_weight = "700";
      padding = "0 18px";
      letter_spacing = "0.08em";
    })
    (waybarFramework.rule "#mpris" {
      color = colors.base06;
      font_weight = "600";
      min_width = "220px";
    })
    (waybarFramework.rule "#mpris.paused, #mpris.stopped" {
      color = colors.base04;
    })
    (waybarFramework.rule "#battery" {color = colors.base0A;})
    (waybarFramework.rule "#battery.charging" {color = colors.base0B;})
    (waybarFramework.rule "#battery.warning" {color = colors.base09;})
    (waybarFramework.rule "#battery.critical" {color = colors.base08;})
    (waybarFramework.rule "#cpu, #memory" {color = colors.base0D;})
    (waybarFramework.rule "#cpu.warning, #memory.warning" {color = colors.base09;})
    (waybarFramework.rule "#cpu.critical, #memory.critical" {color = colors.base08;})
    (waybarFramework.rule "#custom-power" {
      color = colors.base0E;
      min_width = "20px";
      padding = "0 10px";
    })
    (waybarFramework.rule "#custom-power:hover" {
      color = colors.base08;
      background = colors.base01;
    })
    (waybarFramework.rule "#network" {color = colors.base0C;})
    (waybarFramework.rule "#network.disconnected" {color = colors.base08;})
    (waybarFramework.rule "#pulseaudio" {color = colors.base0E;})
    (waybarFramework.rule "#pulseaudio.muted" {color = colors.base04;})
    (waybarFramework.rule "#tray" {color = colors.base05;})
    (waybarFramework.rule "#idle_inhibitor" {color = colors.base05;})
    (waybarFramework.rule "#idle_inhibitor.activated" {color = colors.base0A;})
    (waybarFramework.rule "#mpris, #clock, #network, #pulseaudio, #battery, #cpu, #memory, #custom-power, #idle_inhibitor, #tray" {
      background = colors.base01;
      margin = "6px 4px";
      padding = "0 13px";
      border = "1px solid ${colors.base03}";
      border_radius = "12px";
      box_shadow = "inset 0 1px 0 ${colors.base02}";
    })
    (waybarFramework.rule "tooltip" {
      background = colors.base00;
      color = colors.base07;
      border = "1px solid ${colors.base03}";
      border_radius = "14px";
      padding = "6px 10px";
      box_shadow = "0 12px 28px ${colors.base00}";
    })
    (waybarFramework.rule "tooltip label" {color = colors.base06;})
  ];

  mainBar = waybarFramework.bar {
    layer = "top";
    position = "top";
    height = 42;
    margin-top = 14;
    margin-left = 18;
    margin-right = 18;
    spacing = 6;
    modules-left = ["niri/workspaces"];
    modules-center = ["mpris"];
    modules-right = ["idle_inhibitor" "clock" "network" "pulseaudio" "battery" "cpu" "memory" "tray" "custom/power"];

    mpris = {
      format = "{player_icon}  {dynamic}";
      format-paused = "{status_icon}  {dynamic}";
      dynamic-len = 36;
      dynamic-order = ["artist" "title"];
      player-icons.default = "󰎆";
      status-icons.paused = "󰏤";
      status-icons.stopped = "󰓛";
      tooltip-format = "{player} - {title}\n{artist}";
    };

    clock = {
      format = "{:%H:%M}";
      format-alt = "{:%a %d %b}";
      tooltip-format = "<big>{:%A}</big>\n<tt>{calendar}</tt>";
    };

    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "󰅶";
        deactivated = "󰛊";
      };
      tooltip-format-activated = "Idle inhibitor on";
      tooltip-format-deactivated = "Idle inhibitor off";
    };

    network = {
      format-wifi = "󰤨  {signalStrength}%";
      format-ethernet = "󰈀  wired";
      format-disconnected = "󰤮  offline";
      tooltip-format-wifi = "{essid} ({signalStrength}%)";
      tooltip-format-ethernet = "{ifname}";
      tooltip-format-disconnected = "No network";
    };

    pulseaudio = {
      format = "{icon}  {volume}%";
      format-muted = "󰝟  mute";
      format-icons.default = ["" "" ""];
    };

    battery = {
      format = "{icon}  {capacity}%";
      format-charging = "󰂄  {capacity}%";
      format-warning = "󰂃  {capacity}%";
      format-critical = "󰁺  {capacity}%";
      format-icons = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
    };

    cpu = {
      format = "  {usage}%";
      tooltip = false;
    };

    memory = {
      format = "󰍛  {}%";
      tooltip = false;
    };

    tray.spacing = 10;

    "custom/power" = {
      format = "⏻";
      tooltip = false;
      on-click = "wlogout";
    };
  };
in {
  config = lib.mkIf config.programs.waybar.enable {
    home.packages = [pkgs.siji];
    programs.waybar = {
      package = pkgs.waybar;
      settings = [mainBar];
    };
    xdg.configFile."waybar/style.css" = lib.mkForce {source = pkgs.writeText "waybar-style.css" waybarStyle;};
  };
}
