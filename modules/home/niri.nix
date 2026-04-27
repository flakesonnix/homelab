{ lib, config, pkgs, ... }:

let
  workspaceBinds =
    lib.concatMapStringsSep "\n"
      (
        n:
        let
          id = toString n;
        in
        ''
          Mod+${id} { focus-workspace ${id}; }
          Mod+Ctrl+${id} { move-column-to-workspace ${id}; }
          Mod+Shift+${id} { move-window-to-workspace ${id}; }
        ''
      )
      (lib.range 1 9);
in

{
  options.lucy.niri = {
    enable = lib.mkEnableOption "Niri compositor config";
  };

  config = lib.mkIf config.lucy.niri.enable {
    xdg.configFile."niri/config.kdl".force = true;
    xdg.configFile."niri/config.kdl".text = ''
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

            layout {
              gaps 16
              default-column-width { proportion 0.5; }

              focus-ring {
                off
              }

              border {
                width 2
                active-gradient from="#ff69b4" to="#c678dd" angle=45
                inactive-color "#2a2436"
              }

              shadow {
                on
                softness 30
                spread 5
                offset x=0 y=5
                color "#ff69b433"
              }

              background-color "transparent"
            }

            spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
            spawn-at-startup "${pkgs.waybar}/bin/waybar"
            spawn-at-startup "${pkgs.swaybg}/bin/swaybg" "-i" "${config.home.sessionVariables.WALLPAPER}" "-m" "fill"
            spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite"

            prefer-no-csd

            screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

            animations {}

            window-rule {
              match app-id=r#"^org\.wezfurlong\.wezterm$"#
              default-column-width {}
            }

            window-rule {
              match app-id=r#"firefox$"# title="^Picture-in-Picture$"
              open-floating true
            }

            window-rule {
              geometry-corner-radius 12
              clip-to-geometry true
            }

            binds {
              Mod+Shift+Slash { show-hotkey-overlay; }

              Mod+Return hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
              Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }
              Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "${pkgs.swaylock-fancy}/bin/swaylock-fancy"; }

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

              Mod+O repeat=false { toggle-overview; }

              Mod+W repeat=false { close-window; }

              Mod+Left  { focus-column-left; }
              Mod+Down  { focus-window-down; }
              Mod+Up    { focus-window-up; }
              Mod+Right { focus-column-right; }
              Mod+H     { focus-column-left; }
              Mod+J     { focus-window-down; }
              Mod+K     { focus-window-up; }
              Mod+L     { focus-column-right; }

              Mod+Ctrl+Left  { move-column-left; }
              Mod+Ctrl+Down  { move-window-down; }
              Mod+Ctrl+Up    { move-window-up; }
              Mod+Ctrl+Right { move-column-right; }
              Mod+Ctrl+H     { move-column-left; }
              Mod+Ctrl+J     { move-window-down; }
              Mod+Ctrl+K     { move-window-up; }
              Mod+Ctrl+L     { move-column-right; }

              Mod+Home { focus-column-first; }
              Mod+End  { focus-column-last; }
              Mod+Ctrl+Home { move-column-to-first; }
              Mod+Ctrl+End  { move-column-to-last; }

              Mod+Shift+Left  { focus-monitor-left; }
              Mod+Shift+Down  { focus-monitor-down; }
              Mod+Shift+Up    { focus-monitor-up; }
              Mod+Shift+Right { focus-monitor-right; }
              Mod+Shift+H     { focus-monitor-left; }
              Mod+Shift+J     { focus-monitor-down; }
              Mod+Shift+K     { focus-monitor-up; }
              Mod+Shift+L     { focus-monitor-right; }

              Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
              Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
              Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
              Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
              Mod+Shift+Ctrl+H     { move-column-to-monitor-left; }
              Mod+Shift+Ctrl+J     { move-column-to-monitor-down; }
              Mod+Shift+Ctrl+K     { move-column-to-monitor-up; }
              Mod+Shift+Ctrl+L     { move-column-to-monitor-right; }

              Mod+Page_Down      { focus-workspace-down; }
              Mod+Page_Up        { focus-workspace-up; }
              Mod+U              { focus-workspace-down; }
              Mod+I              { focus-workspace-up; }
              Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
              Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
              Mod+Ctrl+U         { move-column-to-workspace-down; }
              Mod+Ctrl+I         { move-column-to-workspace-up; }

              Mod+Shift+Page_Down { move-workspace-down; }
              Mod+Shift+Page_Up   { move-workspace-up; }
              Mod+Shift+U         { move-workspace-down; }
              Mod+Shift+I         { move-workspace-up; }

              Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
              Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
              Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
              Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

              Mod+WheelScrollRight      { focus-column-right; }
              Mod+WheelScrollLeft       { focus-column-left; }
              Mod+Ctrl+WheelScrollRight { move-column-right; }
              Mod+Ctrl+WheelScrollLeft  { move-column-left; }

              Mod+Shift+WheelScrollDown      { focus-column-right; }
              Mod+Shift+WheelScrollUp        { focus-column-left; }
              Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
              Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

      ${workspaceBinds}

              Mod+BracketLeft  { consume-or-expel-window-left; }
              Mod+BracketRight { consume-or-expel-window-right; }

              Mod+Comma  { consume-window-into-column; }
              Mod+Period { expel-window-from-column; }

              Mod+R { switch-preset-column-width; }
              Mod+Shift+R { switch-preset-column-width-back; }

              Mod+Ctrl+Shift+R { switch-preset-window-height; }
              Mod+Ctrl+R { reset-window-height; }

              Mod+F { maximize-column; }
              Mod+Shift+F { fullscreen-window; }

              Mod+M { maximize-window-to-edges; }

              Mod+Ctrl+F { expand-column-to-available-width; }

              Mod+C { center-column; }

              Mod+Ctrl+C { center-visible-columns; }

              Mod+Minus { set-column-width "-10%"; }
              Mod+Equal { set-column-width "+10%"; }

              Mod+Shift+Minus { set-window-height "-10%"; }
              Mod+Shift+Equal { set-window-height "+10%"; }

              Mod+V       { toggle-window-floating; }
              Mod+Shift+V { switch-focus-between-floating-and-tiling; }

        

              Print { screenshot; }
              Ctrl+Print { screenshot-screen; }
              Alt+Print { screenshot-window; }
              Mod+Shift+S { screenshot; }
              Mod+Ctrl+Shift+S { screenshot-screen; }
              Mod+Alt+Shift+S { screenshot-window; }

              Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

              Mod+Shift+E { quit; }
              Ctrl+Alt+Delete { quit; }

              Mod+Shift+P { power-off-monitors; }
            }
    '';

    home.packages = [ pkgs.wl-clipboard pkgs.swaylock-fancy ];
  };
}
