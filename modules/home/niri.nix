{
  lib,
  config,
  pkgs,
  frameworkLib,
  ...
}: let
  projectLib = frameworkLib;
  theme = projectLib.theme.fromStylix config;
  inherit (theme) colors gradient hexAlpha rgba;
  inherit (projectLib) symbols;
  keys = projectLib.framework.keys {inherit symbols;};
  actions = projectLib.framework.actions {inherit symbols;};
  niriFramework = projectLib.framework.niri;
  renderCommand = projectLib.render.command.render;
  renderBind = projectLib.render.kdl.renderBind renderCommand;
  inherit (projectLib.render.kdl) renderCommandBlock renderLeaf renderLines renderPropsBlock renderSection;

  mkBuiltinBind = key: actionName:
    renderBind (niriFramework.bind key (actions.builtin actionName));
  mkBindWithAttrs = key: attrs: action:
    renderBind (niriFramework.bindWith key attrs action);
  mkScrollBind = key: actionName:
    mkBindWithAttrs key {cooldown-ms = 150;} (actions.builtin actionName);
  mkWorkspaceBind = n:
    map renderBind (niriFramework.workspaceBindTriplet {
      focusKey = keys.alt (keys.workspace n);
      moveColumnKey = keys.altCtrl (keys.workspace n);
      moveWindowKey = keys.altShift (keys.workspace n);
      workspace = n;
      inherit actions symbols;
    });
  mkWlogoutEntry = label: action: text: keybind: {
    inherit label action text keybind;
  };
  renderStartup = command:
    if command.kind == "spawn"
    then renderCommandBlock "spawn-at-startup" command.argv
    else if command.kind == "spawn-sh"
    then ''spawn-at-startup "sh" "-lc" ${builtins.toJSON command.script}''
    else throw "Unsupported startup command kind";
  renderWindowRule = rule: renderSection "window-rule" rule.lines;
  lockCommand = "sh -c '${lib.getExe' pkgs.swaylock-effects "swaylock"} --screenshots --clock --indicator --indicator-radius 110 --indicator-thickness 10 --effect-blur 7x5 --effect-vignette 0.25:0.6 --fade-in 0.2 --font Inter --font-size 24 --timestr %H:%M --datestr %a,\ %d\ %b --text-color ${hexAlpha colors.base07 "ff"} --text-clear-color ${hexAlpha colors.base07 "ff"} --text-ver-color ${hexAlpha colors.base0A "ff"} --text-wrong-color ${hexAlpha colors.base08 "ff"} --inside-color ${hexAlpha colors.base00 "96"} --inside-clear-color ${hexAlpha colors.base01 "d6"} --inside-ver-color ${hexAlpha colors.base02 "d6"} --inside-wrong-color ${hexAlpha colors.base01 "d6"} --ring-color ${hexAlpha colors.base0E "e0"} --ring-clear-color ${hexAlpha colors.base0C "d0"} --ring-ver-color ${hexAlpha colors.base0A "d0"} --ring-wrong-color ${hexAlpha colors.base08 "d0"} --line-color 00000000 --separator-color 00000000 --key-hl-color ${hexAlpha colors.base0E "ff"} --bs-hl-color ${hexAlpha colors.base0C "ff"} --show-failed-attempts --daemonize'";
  startupCommands = renderLines (map renderStartup (
    [
      (niriFramework.startupSpawn ["${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"])
      (niriFramework.startupSpawn [(lib.getExe pkgs.swaybg) "-m" "fill" "-i" config.home.sessionVariables.WALLPAPER])
      (niriFramework.startupSpawn [(lib.getExe pkgs.xwayland-satellite)])
    ]
    ++ lib.optionals config.programs.waybar.enable [
      (niriFramework.startupSpawn [(lib.getExe pkgs.waybar)])
    ]
    ++ lib.optionals (config.programs.eww.enable or false) [
      (niriFramework.startupSpawn [(lib.getExe pkgs.eww) "daemon"])
      (niriFramework.startupSpawn [(lib.getExe pkgs.eww) "open" "topbar"])
      (niriFramework.startupSpawn [(lib.getExe pkgs.eww) "open" "sidebar"])
    ]
  ));

  windowRules = renderLines (map renderWindowRule [
    (niriFramework.windowRule [
      ''match app-id=r#"firefox$"# title="^Picture-in-Picture$"''
      "open-floating true"
    ])
    (niriFramework.windowRule [
      "geometry-corner-radius 16"
      "clip-to-geometry true"
    ])
  ]);

  inputSection = renderSection "input" [
    (renderPropsBlock "keyboard" [
      "xkb {}"
      (niriFramework.leaf "numlock" null)
    ])
    (renderPropsBlock "touchpad" [
      (niriFramework.leaf "tap" null)
      (niriFramework.leaf "natural-scroll" null)
    ])
  ];

  layoutSection = renderSection "layout" [
    (renderLeaf "gaps" 22)
    (renderLeaf "center-focused-column" "on-overflow")
    "default-column-width { proportion 0.5; }"
    (renderPropsBlock "focus-ring" [
      (niriFramework.leaf "off" null)
    ])
    (renderPropsBlock "border" [
      (niriFramework.leaf "width" 3)
      (niriFramework.leaf "active-color" colors.base0E)
      (niriFramework.leaf "inactive-color" colors.base03)
    ])
    (renderPropsBlock "shadow" [
      (niriFramework.leaf "on" null)
      (niriFramework.leaf "softness" 48)
      (niriFramework.leaf "spread" 0)
      "offset x=0 y=14"
      (niriFramework.leaf "color" (rgba colors.base0E "26"))
    ])
    (renderLeaf "background-color" "transparent")
  ];

  workspaceBinds = renderLines (builtins.concatLists (map mkWorkspaceBind (lib.range 1 9)));

  staticBinds = ''
    ${mkBuiltinBind (keys.altShift symbols.keys.slash) "show-hotkey-overlay"}

    ${mkBindWithAttrs (keys.alt symbols.keys.enter) {hotkey-overlay-title = "Open a Terminal: alacritty";} (actions.spawn ["${lib.getExe pkgs.alacritty}"])}
    ${mkBindWithAttrs (keys.alt "D") {hotkey-overlay-title = "Run an Application: fuzzel";} (actions.spawn ["${lib.getExe pkgs.fuzzel}"])}
    ${mkBindWithAttrs (keys.altCtrl symbols.keys.escape) {hotkey-overlay-title = "Lock the Screen: swaylock";} (actions.shell lockCommand)}

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

    ${mkBindWithAttrs (keys.alt "O") {repeat = false;} actions.named.toggleOverview}
    ${mkBindWithAttrs (keys.alt "W") {repeat = false;} actions.named.closeWindow}

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

    Alt+Page_Down { focus-workspace-down; }
    Alt+Page_Up   { focus-workspace-up; }
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

    ${mkScrollBind "Alt+WheelScrollDown" "focus-workspace-down"}
    ${mkScrollBind "Alt+WheelScrollUp" "focus-workspace-up"}
    ${mkScrollBind "Alt+Ctrl+WheelScrollDown" "move-column-to-workspace-down"}
    ${mkScrollBind "Alt+Ctrl+WheelScrollUp" "move-column-to-workspace-up"}

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
    ${mkBuiltinBind "Alt+BracketLeft" "consume-or-expel-window-left"}
    ${mkBuiltinBind "Alt+BracketRight" "consume-or-expel-window-right"}

    ${mkBuiltinBind "Alt+Comma" "consume-window-into-column"}
    ${mkBuiltinBind "Alt+Period" "expel-window-from-column"}

    ${mkBuiltinBind "Alt+R" "switch-preset-column-width"}
    ${mkBuiltinBind "Alt+Shift+R" "switch-preset-column-width-back"}

    ${mkBuiltinBind "Alt+Ctrl+Shift+R" "switch-preset-window-height"}
    ${mkBuiltinBind "Alt+Ctrl+R" "reset-window-height"}

    ${mkBuiltinBind "Alt+F" "maximize-column"}
    ${mkBuiltinBind "Alt+Shift+F" "fullscreen-window"}

    ${mkBuiltinBind "Alt+M" "maximize-window-to-edges"}

    ${mkBuiltinBind "Alt+Ctrl+F" "expand-column-to-available-width"}

    ${mkBuiltinBind "Alt+C" "center-column"}

    ${mkBuiltinBind "Alt+Ctrl+C" "center-visible-columns"}

    Alt+Minus { set-column-width "-10%"; }
    Alt+Equal { set-column-width "+10%"; }

    Alt+Shift+Minus { set-window-height "-10%"; }
    Alt+Shift+Equal { set-window-height "+10%"; }

    ${mkBuiltinBind "Alt+V" "toggle-window-floating"}
    ${mkBuiltinBind "Alt+Shift+V" "switch-focus-between-floating-and-tiling"}

    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }
    Alt+Shift+S { screenshot; }
    Alt+Ctrl+Shift+S { screenshot-screen; }
    Alt+Ctrl+Shift+W { screenshot-window; }

    Alt+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

    ${mkBuiltinBind "Alt+Shift+E" symbols.actions.quit}
    Ctrl+Alt+Delete { quit; }

    ${mkBuiltinBind "Alt+Shift+P" symbols.actions.powerOffMonitors}
  '';

  niriConfig = lib.concatStringsSep "\n\n" [
    inputSection
    layoutSection
    startupCommands
    ''prefer-no-csd''
    ''screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"''
    ''      animations {
            workspace-switch {
              spring damping-ratio=0.72 stiffness=800 epsilon=0.0001
            }
            window-open {
              duration-ms 380
              curve "ease-out-expo"
            }
            window-close {
              duration-ms 100
              curve "ease-out-quad"
            }
            window-movement {
              spring damping-ratio=0.68 stiffness=700 epsilon=0.0001
            }
            window-resize {
              spring damping-ratio=0.92 stiffness=1400 epsilon=0.0001
            }
            horizontal-view-movement {
              spring damping-ratio=0.82 stiffness=600 epsilon=0.0001
            }
            config-notification-open-close {
              spring damping-ratio=0.45 stiffness=550 epsilon=0.001
            }
          }''
    windowRules
    ''
      binds {
        ${lib.concatStringsSep "\n" [staticBinds workspaceBinds trailingBinds]}
      }
    ''
  ];
in {
  options.programs.niri.enable = lib.mkEnableOption "Niri compositor config";

  config = lib.mkIf config.programs.niri.enable {
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
        border-size = 2;
        border-radius = 18;
        default-timeout = 5000;
        background-color = rgba colors.base00 "e6";
        text-color = colors.base07;
        border-color = rgba colors.base0E "c8";
        progress-color = "over ${rgba colors.base0E "cc"}";
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
        border-color=${rgba colors.base0D "66"}
        default-timeout=3000

        [urgency=normal]
        border-color=${rgba colors.base0E "99"}

        [urgency=high]
        background-color=${rgba colors.base08 "ee"}
        border-color=${rgba colors.base08 "cc"}
        text-color=${colors.base07}
        default-timeout=0
      '';
    };
    xdg.configFile."wlogout/layout".source = pkgs.writeText "layout" (builtins.toJSON [
      (mkWlogoutEntry "lock" lockCommand "Lock" "l")
      (mkWlogoutEntry "logout" "loginctl kill-user $USER" "Logout" "e")
      (mkWlogoutEntry "suspend" "systemctl suspend" "Sleep" "u")
      (mkWlogoutEntry "reboot" "systemctl reboot" "Restart" "r")
      (mkWlogoutEntry "shutdown" "systemctl poweroff" "Shutdown" "s")
    ]);
    xdg.configFile."wlogout/style.css".source = pkgs.writeText "style.css" ''
      * {
        background-image: none;
        box-shadow: none;
        font-family: "Inter", sans-serif;
      }

      window {
        background: ${gradient "145deg" [(rgba colors.base00 "f0") (rgba colors.base01 "e8") (rgba colors.base02 "de")]};
        border: 1px solid ${rgba colors.base0E "54"};
        border-radius: 24px;
        box-shadow: 0 24px 64px ${rgba colors.base00 "b8"};
      }

      button {
        color: ${colors.base05};
        background: ${gradient "135deg" [(rgba colors.base01 "c8") (rgba colors.base02 "b8")]};
        border: 1px solid ${rgba colors.base0E "52"};
        border-radius: 20px;
        margin: 12px;
        padding: 20px 28px;
        font-size: 14px;
        font-weight: 600;
        letter-spacing: 0.04em;
        transition: all 150ms ease;
        backdrop-filter: blur(24px);
      }

      button:hover {
        background: ${gradient "135deg" [(rgba colors.base0E "88") (rgba colors.base0D "74") (rgba colors.base0C "50")]};
        color: ${colors.base07};
        border-color: ${rgba colors.base0E "b8"};
      }
    '';

    home.packages = with pkgs; [
      blueman
      brightnessctl
      grim
      networkmanagerapplet
      playerctl
      slurp
      swaylock-effects
      wl-clipboard
      wlogout
    ];
  };
}
