{
  lib,
  config,
  pkgs,
  ...
}: let
  toCSS = rules: let
    renderBlock = sel: attrs: let
      renderDecl = name: val: let
        dashify = s: lib.replaceStrings ["_"] ["-"] s;
        toVal = v:
          if lib.isString v
          then v
          else if lib.isList v
          then lib.concatStringsSep ", " v
          else toString v;
      in "${
        if lib.hasPrefix "-" name
        then name
        else dashify name
      }: ${toVal val};";
    in "${sel} {\n${lib.concatStringsSep "\n" (lib.mapAttrsToList renderDecl attrs)}\n}";
    fold = acc: rule:
      if lib.isAttrs rule
      then acc + (lib.concatStringsSep "\n" (lib.mapAttrsToList renderBlock rule)) + "\n"
      else if lib.isString rule
      then acc + rule + "\n"
      else acc;
  in
    builtins.foldl' fold "" rules;

  waybarStyle = toCSS [
    {
      "*" = {
        font_family = ["Inter" "Hack Nerd Font" "sans-serif"];
        font_size = "14px";
        min_height = "0";
      };
    }
    {
      "window#waybar" = {
        background = "linear-gradient(90deg, rgba(18, 18, 34, 0.88), rgba(32, 24, 44, 0.84), rgba(26, 28, 58, 0.84))";
        color = "#f7f4ff";
        border = "1px solid rgba(255, 214, 236, 0.18)";
        border_radius = "18px";
        box_shadow = "0 14px 34px rgba(8, 8, 18, 0.34)";
      };
    }
    {
      "window#waybar.dock" = {
        background = "linear-gradient(90deg, rgba(18, 18, 34, 0.88), rgba(32, 24, 44, 0.84), rgba(26, 28, 58, 0.84))";
        color = "#f7f4ff";
        border = "1px solid rgba(255, 214, 236, 0.18)";
        border_radius = "18px";
        box_shadow = "0 14px 34px rgba(8, 8, 18, 0.34)";
      };
    }
    {
      "#workspaces" = {
        margin_left = "0";
        padding = "0 6px";
      };
    }
    {
      "#workspaces button" = {
        color = "#d8cce8";
        padding = "4px 12px";
        margin = "3px 2px";
        border_radius = "12px";
        border = "1px solid transparent";
        text_shadow = "0 1px 3px rgba(0, 0, 0, 0.2)";
        transition = "all 150ms ease";
      };
    }
    {
      "#workspaces button:hover" = {
        color = "#ffffff";
        background = "rgba(255, 214, 236, 0.12)";
        border = "1px solid rgba(255, 214, 236, 0.12)";
      };
    }
    {
      "#workspaces button.active" = {
        color = "#ffffff";
        background = "linear-gradient(90deg, rgba(236, 160, 204, 0.35), rgba(173, 190, 255, 0.26))";
        border = "1px solid rgba(255, 226, 241, 0.24)";
        box_shadow = "0 6px 18px rgba(12, 12, 24, 0.24)";
      };
    }
    {
      "#workspaces button.urgent" = {
        background = "rgba(255, 122, 122, 0.2)";
        color = "#fff4f4";
      };
    }
    {
      "#clock" = {
        color = "#ffffff";
        font_weight = "700";
        padding = "0 18px";
        letter_spacing = "0.08em";
      };
    }
    {
      "#mpris" = {
        color = "#fff3fb";
        font_weight = "600";
        min_width = "220px";
      };
    }
    {
      "#mpris.paused, #mpris.stopped" = {
        color = "#a99fbb";
      };
    }
    {"#battery" = {color = "#fff1cf";};}
    {"#battery.charging" = {color = "#80ff80";};}
    {"#battery.warning" = {color = "#ffb86c";};}
    {"#battery.critical" = {color = "#ff5555";};}
    {"#cpu, #memory" = {color = "#c9d7ff";};}
    {"#cpu.warning, #memory.warning" = {color = "#ffb86c";};}
    {"#cpu.critical, #memory.critical" = {color = "#ff5555";};}
    {
      "#custom-power" = {
        color = "#ffcedf";
        min_width = "20px";
        padding = "0 10px";
      };
    }
    {
      "#custom-power:hover" = {
        color = "#ff5555";
        background = "rgba(255, 85, 85, 0.1)";
      };
    }
    {"#network" = {color = "#dff1ff";};}
    {"#network.disconnected" = {color = "#ff5555";};}
    {"#pulseaudio" = {color = "#ffd9ee";};}
    {"#pulseaudio.muted" = {color = "#7a7088";};}
    {"#tray" = {color = "#d9d0f2";};}
    {"#idle_inhibitor" = {color = "#d9d0f2";};}
    {"#idle_inhibitor.activated" = {color = "#fff1cf";};}
    {
      "#mpris, #clock, #network, #pulseaudio, #battery, #cpu, #memory, #custom-power, #idle_inhibitor, #tray" = {
        background = "rgba(255, 255, 255, 0.07)";
        margin = "6px 4px";
        padding = "0 13px";
        border = "1px solid rgba(255, 255, 255, 0.07)";
        border_radius = "12px";
        box_shadow = "inset 0 1px 0 rgba(255, 255, 255, 0.05)";
      };
    }
    {
      "tooltip" = {
        background = "rgba(20, 18, 36, 0.95)";
        color = "#efeaff";
        border = "1px solid rgba(255, 214, 236, 0.14)";
        border_radius = "14px";
        padding = "6px 10px";
        box_shadow = "0 12px 28px rgba(0, 0, 0, 0.32)";
      };
    }
    {"tooltip label" = {color = "#d9d0f2";};}
  ];
in {
  options.lucy.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.lucy.waybar.enable {
    home.packages = [pkgs.siji];
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
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

          tray = {
            spacing = 10;
          };

          "custom/power" = {
            format = "⏻";
            tooltip = false;
            on-click = "wlogout";
          };
        }
      ];
    };
    xdg.configFile."waybar/style.css" = lib.mkForce {source = pkgs.writeText "waybar-style.css" waybarStyle;};
  };
}
