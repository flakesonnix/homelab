{
  lib,
  config,
  pkgs,
  ...
}: let
  lockCommand = "sh -c '${pkgs.swaylock-effects}/bin/swaylock --screenshots --clock --indicator --indicator-radius 110 --indicator-thickness 8 --effect-blur 7x5 --effect-vignette 0.25:0.6 --fade-in 0.2 --font Inter --font-size 24 --timestr %H:%M --datestr %a,\ %d\ %b --text-color f7f4ffff --text-clear-color f7f4ffff --text-ver-color fff1cfff --text-wrong-color ffd7eaff --inside-color 16162688 --inside-clear-color 322347cc --inside-ver-color 5c4b2acc --inside-wrong-color 4d2234cc --ring-color e7a6cbcc --ring-clear-color adc2ffcc --ring-ver-color f2d58acc --ring-wrong-color ff8db6cc --line-color 00000000 --separator-color 00000000 --key-hl-color ffd6ecff --bs-hl-color adc2ffff --show-failed-attempts --daemonize'";
  startupCommands = lib.concatStringsSep "\n" [
    ''spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"''
    ''spawn-at-startup "${pkgs.waybar}/bin/waybar"''
    ''spawn-at-startup "${pkgs.awww}/bin/awww-daemon"''
    ''spawn-at-startup "sh" "-lc" "sleep 0.4 && ${pkgs.awww}/bin/awww img --resize crop --filter Lanczos3 --transition-type grow --transition-pos top-right --transition-step 90 --transition-duration 1.2 --transition-fps 60 ${config.home.sessionVariables.WALLPAPER}"''
    ''spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite"''
  ];

  windowRules = lib.concatStringsSep "\n\n" [
    ''
      window-rule {
        match app-id=r#"^org\.wezfurlong\.wezterm$"#
        default-column-width {}
      }
    ''
    ''
      window-rule {
        match app-id=r#"firefox$"# title="^Picture-in-Picture$"
        open-floating true
      }
    ''
    ''
      window-rule {
        geometry-corner-radius 16
        clip-to-geometry true
      }
    ''
  ];

  workspaceBinds =
    lib.concatMapStringsSep "\n"
    (
      n: let
        id = toString n;
      in ''
        Alt+${id} { focus-workspace ${id}; }
        Alt+Ctrl+${id} { move-column-to-workspace ${id}; }
        Alt+Shift+${id} { move-window-to-workspace ${id}; }
      ''
    )
    (lib.range 1 9);

  staticBinds = ''
    Alt+Shift+Slash { show-hotkey-overlay; }

    Alt+Return hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
    Alt+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }
    Alt+Ctrl+Escape hotkey-overlay-title="Lock the Screen: swaylock" { spawn-sh "${lockCommand}"; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

    XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
    XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
    XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

    XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }

    Alt+O repeat=false { toggle-overview; }

    Alt+W repeat=false { close-window; }

    Alt+Left  { focus-column-left; }
    Alt+Down  { focus-window-down; }
    Alt+Up    { focus-window-up; }
    Alt+Right { focus-column-right; }
    Alt+H     { focus-column-left; }
    Alt+J     { focus-window-down; }
    Alt+K     { focus-window-up; }
    Alt+L     { focus-column-right; }

    Alt+Ctrl+Left  { move-column-left; }
    Alt+Ctrl+Down  { move-window-down; }
    Alt+Ctrl+Up    { move-window-up; }
    Alt+Ctrl+Right { move-column-right; }
    Alt+Ctrl+H     { move-column-left; }
    Alt+Ctrl+J     { move-window-down; }
    Alt+Ctrl+K     { move-window-up; }
    Alt+Ctrl+L     { move-column-right; }

    Alt+Home { focus-column-first; }
    Alt+End  { focus-column-last; }
    Alt+Ctrl+Home { move-column-to-first; }
    Alt+Ctrl+End  { move-column-to-last; }

    Alt+Shift+Left  { focus-monitor-left; }
    Alt+Shift+Down  { focus-monitor-down; }
    Alt+Shift+Up    { focus-monitor-up; }
    Alt+Shift+Right { focus-monitor-right; }
    Alt+Shift+H     { focus-monitor-left; }
    Alt+Shift+J     { focus-monitor-down; }
    Alt+Shift+K     { focus-monitor-up; }
    Alt+Shift+L     { focus-monitor-right; }

    Alt+Shift+Ctrl+Left  { move-column-to-monitor-left; }
    Alt+Shift+Ctrl+Down  { move-column-to-monitor-down; }
    Alt+Shift+Ctrl+Up    { move-column-to-monitor-up; }
    Alt+Shift+Ctrl+Right { move-column-to-monitor-right; }
    Alt+Shift+Ctrl+H     { move-column-to-monitor-left; }
    Alt+Shift+Ctrl+J     { move-column-to-monitor-down; }
    Alt+Shift+Ctrl+K     { move-column-to-monitor-up; }
    Alt+Shift+Ctrl+L     { move-column-to-monitor-right; }

    Alt+Page_Down      { focus-workspace-down; }
    Alt+Page_Up        { focus-workspace-up; }
    Alt+U              { focus-workspace-down; }
    Alt+I              { focus-workspace-up; }
    Alt+Ctrl+Page_Down { move-column-to-workspace-down; }
    Alt+Ctrl+Page_Up   { move-column-to-workspace-up; }
    Alt+Ctrl+U         { move-column-to-workspace-down; }
    Alt+Ctrl+I         { move-column-to-workspace-up; }

    Alt+Shift+Page_Down { move-workspace-down; }
    Alt+Shift+Page_Up   { move-workspace-up; }
    Alt+Shift+U         { move-workspace-down; }
    Alt+Shift+I         { move-workspace-up; }

    Alt+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
    Alt+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
    Alt+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
    Alt+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

    Alt+WheelScrollRight      { focus-column-right; }
    Alt+WheelScrollLeft       { focus-column-left; }
    Alt+Ctrl+WheelScrollRight { move-column-right; }
    Alt+Ctrl+WheelScrollLeft  { move-column-left; }

    Alt+Shift+WheelScrollDown      { focus-column-right; }
    Alt+Shift+WheelScrollUp        { focus-column-left; }
    Alt+Ctrl+Shift+WheelScrollDown { move-column-right; }
    Alt+Ctrl+Shift+WheelScrollUp   { move-column-left; }
  '';

  trailingBinds = ''
    Alt+BracketLeft  { consume-or-expel-window-left; }
    Alt+BracketRight { consume-or-expel-window-right; }

    Alt+Comma  { consume-window-into-column; }
    Alt+Period { expel-window-from-column; }

    Alt+R { switch-preset-column-width; }
    Alt+Shift+R { switch-preset-column-width-back; }

    Alt+Ctrl+Shift+R { switch-preset-window-height; }
    Alt+Ctrl+R { reset-window-height; }

    Alt+F { maximize-column; }
    Alt+Shift+F { fullscreen-window; }

    Alt+M { maximize-window-to-edges; }

    Alt+Ctrl+F { expand-column-to-available-width; }

    Alt+C { center-column; }

    Alt+Ctrl+C { center-visible-columns; }

    Alt+Minus { set-column-width "-10%"; }
    Alt+Equal { set-column-width "+10%"; }

    Alt+Shift+Minus { set-window-height "-10%"; }
    Alt+Shift+Equal { set-window-height "+10%"; }

    Alt+V       { toggle-window-floating; }
    Alt+Shift+V { switch-focus-between-floating-and-tiling; }

    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }
    Alt+Shift+S { screenshot; }
    Alt+Ctrl+Shift+S { screenshot-screen; }
    Alt+Ctrl+Shift+W { screenshot-window; }

    Alt+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

    Alt+Shift+E { quit; }
    Ctrl+Alt+Delete { quit; }

    Alt+Shift+P { power-off-monitors; }
  '';

  niriConfig = lib.concatStringsSep "\n\n" [
    ''
      input {
        keyboard {
          xkb {}
          numlock
        }
        touchpad {
          tap
          natural-scroll
        }
      }
    ''
    ''
      layout {
        gaps 18
        center-focused-column "on-overflow"
        default-column-width { proportion 0.5; }

        focus-ring {
          off
        }

        border {
          width 2
          active-color "#e7a6cb"
          inactive-color "#322a43"
        }

        shadow {
          on
          softness 40
          spread 0
          offset x=0 y=10
          color "#120f1f52"
        }

        background-color "transparent"
      }
    ''
    startupCommands
    ''prefer-no-csd''
    ''screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"''
    ''animations {}''
    windowRules
    ''
      binds {
        ${lib.concatStringsSep "\n" [staticBinds workspaceBinds trailingBinds]}
      }
    ''
  ];
in {
  options.lucy.niri = {
    enable = lib.mkEnableOption "Niri compositor config";
  };

  config = lib.mkIf config.lucy.niri.enable {
    xdg.configFile."niri/config.kdl".force = true;
    xdg.configFile."niri/config.kdl".text = niriConfig;
    services.mako = {
      enable = true;
      settings = lib.mkForce {
        anchor = "top-right";
        sort = "-time";
        font = "Inter 12";
        width = 360;
        height = 160;
        margin = "18,18,0";
        padding = "16";
        border-size = 1;
        border-radius = 18;
        default-timeout = 5000;
        background-color = "#161626e6";
        text-color = "#f7f4ff";
        border-color = "#e7a6cb99";
        progress-color = "over #adc2ffcc";
        icons = true;
        max-icon-size = 48;
        layer = "overlay";
      };
      extraConfig = ''
        outer-margin=18
        format=<b>%s</b>\n<span size="small">%b</span>
        markup=1
        actions=1
        history=1
        text-alignment=left
        [urgency=low]
        border-color=#adc2ff66
        default-timeout=3000

        [urgency=normal]
        border-color=#e7a6cb99

        [urgency=high]
        background-color=#2f1825ee
        border-color=#ff8db6cc
        text-color=#fff4f8
        default-timeout=0
      '';
    };
    xdg.configFile."wlogout/layout".source = pkgs.writeText "layout" (builtins.toJSON [
      {
        label = "lock";
        action = lockCommand;
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "loginctl kill-user $USER";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Sleep";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Restart";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
    ]);
    xdg.configFile."wlogout/style.css".source = pkgs.writeText "style.css" (lib.concatStringsSep "\n" [
      "* {"
      "  background-image: none;"
      "  box-shadow: none;"
      "  font-family: \"Inter\", sans-serif;"
      "}"
      ""
      "window {"
      "  background: linear-gradient(135deg, rgba(18, 18, 34, 0.9), rgba(34, 24, 50, 0.88), rgba(28, 30, 58, 0.88));"
      "  border: 1px solid rgba(255, 214, 236, 0.18);"
      "  border-radius: 24px;"
      "}"
      ""
      "button {"
      "  color: #f7f4ff;"
      "  background: rgba(255, 255, 255, 0.07);"
      "  border: 1px solid rgba(255, 214, 236, 0.12);"
      "  border-radius: 20px;"
      "  margin: 12px;"
      "  padding: 20px 28px;"
      "  font-size: 14px;"
      "  font-weight: 600;"
      "  letter-spacing: 0.04em;"
      "  transition: all 150ms ease;"
      "  backdrop-filter: blur(24px);"
      "}"
      ""
      "button:hover {"
      "  background: linear-gradient(135deg, rgba(236, 160, 204, 0.22), rgba(173, 190, 255, 0.18));"
      "  color: #ffffff;"
      "  border-color: rgba(255, 226, 241, 0.22);"
      "}"
    ]);

    home.packages = [pkgs.wl-clipboard pkgs.swaylock-effects pkgs.wlogout];
  };
}
