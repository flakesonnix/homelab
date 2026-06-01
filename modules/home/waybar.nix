{
  lib,
  config,
  pkgs,
  frameworkLib,
  ...
}: let
  projectLib = frameworkLib;
  theme = projectLib.theme.fromStylix config;
  inherit (theme) colors gradient;
  waybarFramework = projectLib.framework.waybar;
  renderCss = projectLib.render.css.renderSheet;
  barGradient = gradient "90deg" [colors.base00 colors.base01 colors.base02];
  panelGradient = gradient "90deg" [colors.base01 colors.base02];
  accentGradient = gradient "90deg" [colors.base0E colors.base0D colors.base0C];
  cardGradient = gradient "135deg" [colors.base01 colors.base02];

  mediaPopupScript = pkgs.writeShellScript "waybar-media-popup" ''
    title=$(${lib.getExe pkgs.playerctl} metadata title 2>/dev/null)
    artist=$(${lib.getExe pkgs.playerctl} metadata artist 2>/dev/null)
    album=$(${lib.getExe pkgs.playerctl} metadata album 2>/dev/null)
    art_url=$(${lib.getExe pkgs.playerctl} metadata mpris:artUrl 2>/dev/null)
    status=$(${lib.getExe pkgs.playerctl} status 2>/dev/null)

    [ -z "$title" ] && exit 0

    body=""
    [ -n "$artist" ] && body="$artist"
    [ -n "$album" ] && body="$body\n$album"

    art_file=""
    if [ -n "$art_url" ]; then
      case "$art_url" in
        file://*)
          art_file="''${art_url#file://}"
          ;;
        http*)
          art_file="/tmp/waybar-media-art.jpg"
          ${lib.getExe pkgs.curl} -sf "$art_url" -o "$art_file" 2>/dev/null
          ;;
      esac
    fi

    icon_arg=""
    [ -n "$art_file" ] && [ -f "$art_file" ] && icon_arg="-i $art_file"

    # shellcheck disable=SC2086
    ${pkgs.libnotify}/bin/notify-send $icon_arg \
      -t 4000 \
      -h string:x-canonical-private-synchronous:media-popup \
      "$title" "$(printf '%b' "$body")"
  '';

  playerPickerScript = pkgs.writeShellScript "waybar-player-picker" ''
    players=$(${lib.getExe pkgs.playerctl} -l 2>/dev/null)
    count=$(printf '%s\n' "$players" | grep -c .)

    if [ "$count" -le 1 ]; then
      ${lib.getExe pkgs.playerctl} next
    else
      selected=$(printf '%s\n' "$players" | ${lib.getExe pkgs.fuzzel} --dmenu --prompt "Player: " --width 30)
      [ -n "$selected" ] && ${lib.getExe pkgs.playerctl} -p "$selected" play-pause
    fi
  '';

  notifScript = pkgs.writeShellScript "waybar-notifications" ''
    output=$(makoctl list 2>&1)
    if echo "$output" | grep -q "DBus\|does not exist\|Error"; then
      printf '{"text":"󰂚","class":"inactive","tooltip":"No notifications"}\n'
      exit 0
    fi
    count=$(echo "$output" | ${lib.getExe pkgs.python3} -c "
    import sys, json
    try:
      d = json.load(sys.stdin)
      print(sum(len(g) for g in d.get('data', [])))
    except Exception:
      print(0)
    " 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
      printf '{"text":"󱅫 %s","class":"active","tooltip":"%s notifications"}\n' "$count" "$count"
    else
      printf '{"text":"󰂚","class":"inactive","tooltip":"No notifications"}\n'
    fi
  '';

  waybarStyle = renderCss [
    (waybarFramework.rule "*" {
      font_family = ["Inter" "Hack Nerd Font" "sans-serif"];
      font_size = "14px";
      min_height = "0";
    })
    # Transparent shell — islands float on it
    (waybarFramework.rule "window#waybar" {
      background = "rgba(0,0,0,0)";
      color = colors.base07;
    })
    (waybarFramework.rule "window#waybar.dock" {
      background = "rgba(0,0,0,0)";
      color = colors.base07;
    })
    # Island bubbles — responsive sizing
    (waybarFramework.rule ".modules-left, .modules-center, .modules-right" {
      background = barGradient;
      border = "1px solid ${colors.base0E}";
      border_radius = "20px";
      box_shadow = "0 18px 42px ${colors.base00}";
      padding = "0 8px";
      margin = "0 0";
    })
    (waybarFramework.rule ".modules-left, .modules-center, .modules-right" {
      min_width = "200px";
    })
    (waybarFramework.rule "#workspaces" {
      margin_left = "0";
      padding = "0 4px";
    })
    (waybarFramework.rule "#workspaces button" {
      color = colors.base05;
      padding = "2px 10px";
      margin = "4px 2px";
      border_radius = "12px";
      background = "rgba(0, 0, 0, 0)";
      border = "1px solid ${colors.base02}";
      transition = "all 150ms ease";
    })
    (waybarFramework.rule "#workspaces button:hover" {
      color = colors.base07;
      background = panelGradient;
      border = "1px solid ${colors.base0D}";
    })
    (waybarFramework.rule "#workspaces button.active" {
      color = colors.base07;
      background = accentGradient;
      border = "1px solid ${colors.base06}";
      box_shadow = "inset 0 0 0 1px ${colors.base06}, inset 0 0 18px ${colors.base0E}";
    })
    (waybarFramework.rule "#workspaces button.urgent" {
      background = colors.base08;
      color = colors.base07;
    })
    (waybarFramework.rule "#clock" {
      color = colors.base07;
      font_weight = "700";
      padding = "0 14px";
      letter_spacing = "0.12em";
    })
    (waybarFramework.rule "#mpris" {
      color = colors.base06;
      font_weight = "600";
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
      padding = "0 8px";
    })
    (waybarFramework.rule "#custom-power:hover" {
      color = colors.base08;
      background = panelGradient;
    })
    (waybarFramework.rule "#network" {color = colors.base0C;})
    (waybarFramework.rule "#network.disconnected" {color = colors.base08;})
    (waybarFramework.rule "#pulseaudio" {color = colors.base0E;})
    (waybarFramework.rule "#pulseaudio.muted" {color = colors.base04;})
    (waybarFramework.rule "#tray" {color = colors.base05;})
    (waybarFramework.rule "#idle_inhibitor" {color = colors.base05;})
    (waybarFramework.rule "#idle_inhibitor.activated" {color = colors.base0A;})
    (waybarFramework.rule "#window" {
      color = colors.base06;
      font_style = "italic";
    })
    (waybarFramework.rule "#custom-notifications" {color = colors.base05;})
    (waybarFramework.rule "#custom-notifications.active" {color = colors.base0A;})
    (waybarFramework.rule "#custom-notifications.inactive" {color = colors.base04;})
    (waybarFramework.rule "#custom-notifications:hover" {
      color = colors.base08;
      background = panelGradient;
    })
    (waybarFramework.rule "tooltip" {
      background = colors.base00;
      color = colors.base07;
      border = "1px solid ${colors.base0E}";
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
    modules-left = ["niri/workspaces" "niri/window"];
    modules-center = ["mpris"];
    modules-right = ["custom/notifications" "idle_inhibitor" "clock" "network" "pulseaudio" "battery" "cpu" "memory" "tray" "custom/power"];

    "niri/window" = {
      format = "{title}";
      rewrite = {"^$" = "";};
      max-length = 30;
    };

    mpris = {
      format = "{player_icon}  {dynamic}";
      format-paused = "{status_icon}  {dynamic}";
      dynamic-len = 25;
      dynamic-order = ["title" "artist"];
      player-icons = {
        default = "󰎆";
        spotify = "󰓇";
        firefox = "󰈹";
        chromium = "󰊯";
        vlc = "󰕼";
        mpv = "󰐹";
      };
      status-icons = {
        paused = "󰏤";
        stopped = "󰓛";
        playing = "󰐊";
      };
      tooltip-format = "{player}\n{title}\n{artist} — {album}\n{status}";
      on-click = "playerctl play-pause";
      on-click-middle = "${mediaPopupScript}";
      on-click-right = "${playerPickerScript}";
      on-scroll-up = "playerctl previous";
      on-scroll-down = "playerctl next";
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
      on-click = "nm-connection-editor";
    };

    pulseaudio = {
      format = "{icon}  {volume}%";
      format-muted = "󰝟  mute";
      format-icons.default = ["" "" ""];
      on-click = "pwvucontrol";
      on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0";
      on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-";
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
      on-click = "alacritty -e btop";
    };

    memory = {
      format = "󰍛  {}%";
      tooltip = false;
      on-click = "alacritty -e btop";
    };

    "custom/notifications" = {
      exec = "${notifScript}";
      return-type = "json";
      interval = 3;
      on-click = "makoctl dismiss --all";
      on-click-right = "makoctl mode toggle";
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
    home.packages = [pkgs.siji pkgs.libnotify pkgs.curl];
    programs.waybar = {
      package = pkgs.waybar;
      settings = [mainBar];
    };
    xdg.configFile."waybar/style.css" = lib.mkForce {source = pkgs.writeText "waybar-style.css" waybarStyle;};
  };
}
