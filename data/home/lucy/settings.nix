{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  stylixImage = ../../../home/lucy/wallpapers/p53.jpg;
  wallpaper = "/home/lucy/Pictures/s-l1600.jpg";
  swayfxEnabled = (osConfig.programs.sway.enable or false) && lib.getName osConfig.programs.sway.package == "swayfx";
  swayPackage = osConfig.programs.sway.package;
  lockCommand = "${lib.getExe pkgs.swaylock} -f";
  # Screenshots mirror the Niri layout: files under ~/Pictures/Screenshots.
  shotArea = pkgs.writeShellScriptBin "sway-shot-area" ''
    set -eu
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" "$dir/area_$(date +%F_%H-%M-%S).png"
  '';
  shotOutput = pkgs.writeShellScriptBin "sway-shot-output" ''
    set -eu
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    ${lib.getExe pkgs.grim} "$dir/screen_$(date +%F_%H-%M-%S).png"
  '';
  shotWindow = pkgs.writeShellScriptBin "sway-shot-window" ''
    set -eu
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    geom="$(${lib.getExe' swayPackage "swaymsg"} -t get_tree | ${lib.getExe pkgs.jq} -j '.. | select(.type?) | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')"
    ${lib.getExe pkgs.grim} -g "$geom" "$dir/window_$(date +%F_%H-%M-%S).png"
  '';
  # NOTE: no helper packages (slurp, wl-clipboard, playerctl, jq) in
  # home.packages. HM installs home.packages via `nix profile`, which
  # aborts activation on any file collision with imperatively installed
  # profile packages (seen with jq.1.gz). Binds and screenshot scripts
  # reference absolute store paths instead, so they work without a
  # profile install.

  cyberdeckScheme = {
    system = "base16";
    name = "Kuromi Cyberdeck";
    author = "OpenCode";
    variant = "dark";
    palette = {
      base00 = "#16121b";
      base01 = "#22192a";
      base02 = "#342341";
      base03 = "#57386e";
      base04 = "#8d73a8";
      base05 = "#f2ddf5";
      base06 = "#f9f0fb";
      base07 = "#fff7ff";
      base08 = "#ff7bb0";
      base09 = "#ffb86c";
      base0A = "#ff9df2";
      base0B = "#9cf6c8";
      base0C = "#7df9ff";
      base0D = "#c69bff";
      base0E = "#ff7de9";
      base0F = "#6d3a8f";
    };
  };
in
  {
    # stylix.image needs a store path (build-time color extraction).
    # WALLPAPER is a runtime path for swaybg on niri startup.

    stylix.polarity = "dark";
    stylix.base16Scheme = cyberdeckScheme;

    home.packages = with pkgs; [
      nvd
      nix-tree
    ];

    home.sessionVariables.WALLPAPER = toString wallpaper;

    programs.nh.osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
  }
  // {
    stylix.image = stylixImage;
  }
  // lib.optionalAttrs swayfxEnabled {
    programs.fuzzel.enable = true;
    programs.i3status.enable = true;
    programs.swaylock.enable = true;

    wayland.windowManager.sway = {
      enable = true;
      package = swayPackage;
      # SwayFX needs a real DRM FD even for `--validate`, which the Nix
      # sandbox cannot provide (fx_renderer fails with "no DRM FD
      # available"). Plain sway validates headless; SwayFX cannot.
      checkConfig = false;
      systemd.dbusImplementation = osConfig.services.dbus.implementation;
      config = {
        # Super as the modifier; binds follow the Niri layout with Super
        # instead of Alt. All Home Manager default binds that use
        # ${modifier} follow automatically.
        modifier = "Mod4";
        floating.modifier = "Mod4";
        terminal = lib.getExe pkgs.alacritty;
        menu = lib.getExe pkgs.fuzzel;
        window.titlebar = false;
        gaps = {
          inner = 10;
          outer = 6;
        };
        input = {
          "*".xkb_layout = "us";
          "type:touchpad" = {
            tap = "enabled";
            natural_scroll = "enabled";
          };
        };
        keybindings = lib.mkOptionDefault (lib.mergeAttrsList [
          {
            "Mod4+Return" = "exec ${lib.getExe pkgs.alacritty}";
            "Mod4+d" = "exec ${lib.getExe pkgs.fuzzel}";
            "Mod4+Ctrl+Escape" = "exec ${lockCommand}";
            "Mod4+Shift+a" = "exec ${lib.getExe pkgs.pwvucontrol}";

            # Close with Super+W like Niri Alt+W; HM defaults to layout tabbed here.
            "Mod4+w" = "kill";
            # Floating toggle like Niri Alt+V; HM defaults to splitv here.
            "Mod4+v" = "floating toggle";
            "Mod4+Shift+v" = "focus mode_toggle";
            # Niri Alt+F (maximize-column) has no Sway equivalent; keep
            # fullscreen on Super+Shift+F and drop the HM default.
            "Mod4+f" = null;
            "Mod4+Shift+f" = "fullscreen toggle";

            # Percent sizing like the Niri column/window presets.
            "Mod4+minus" = "resize shrink width 10 ppt";
            "Mod4+equal" = "resize grow width 10 ppt";
            "Mod4+Shift+minus" = "resize shrink height 10 ppt";
            "Mod4+Shift+equal" = "resize grow height 10 ppt";

            # Focus/move across outputs like the Niri monitor binds.
            "Mod4+Shift+Left" = "focus output left";
            "Mod4+Shift+Down" = "focus output down";
            "Mod4+Shift+Up" = "focus output up";
            "Mod4+Shift+Right" = "focus output right";
            "Mod4+Ctrl+Shift+Left" = "move container to output left";
            "Mod4+Ctrl+Shift+Down" = "move container to output down";
            "Mod4+Ctrl+Shift+Up" = "move container to output up";
            "Mod4+Ctrl+Shift+Right" = "move container to output right";

            # Workspace cycling like Niri U/I and PgUp/PgDn.
            "Mod4+Page_Down" = "workspace next";
            "Mod4+Page_Up" = "workspace prev";
            "Mod4+u" = "workspace next";
            "Mod4+i" = "workspace prev";
            "Mod4+Ctrl+Page_Down" = "move container to workspace next";
            "Mod4+Ctrl+Page_Up" = "move container to workspace prev";
            "Mod4+Ctrl+u" = "move container to workspace next";
            "Mod4+Ctrl+i" = "move container to workspace prev";

            # Center like Niri center-column (applies to floating windows).
            "Mod4+c" = "move position center";

            "Mod4+Shift+e" = "exit";
            "Ctrl+Alt+Delete" = "exit";
            "Mod4+Shift+p" = "output * power off";

            "XF86AudioRaiseVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
            "XF86AudioLowerVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            "XF86AudioMute" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "XF86AudioMicMute" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            "XF86AudioPlay" = "exec ${lib.getExe pkgs.playerctl} play-pause";
            "XF86AudioStop" = "exec ${lib.getExe pkgs.playerctl} stop";
            "XF86AudioPrev" = "exec ${lib.getExe pkgs.playerctl} previous";
            "XF86AudioNext" = "exec ${lib.getExe pkgs.playerctl} next";
            "XF86MonBrightnessUp" = "exec ${lib.getExe pkgs.brightnessctl} set +10%";
            "XF86MonBrightnessDown" = "exec ${lib.getExe pkgs.brightnessctl} set 10%-";

            "Print" = "exec ${lib.getExe shotArea}";
            "Ctrl+Print" = "exec ${lib.getExe shotOutput}";
            "Mod4+Print" = "exec ${lib.getExe shotWindow}";
            "Mod4+Shift+s" = "exec ${lib.getExe shotArea}";
            "Mod4+Ctrl+Shift+s" = "exec ${lib.getExe shotOutput}";
            "Mod4+Ctrl+Shift+w" = "exec ${lib.getExe shotWindow}";
          }
          # Niri moves columns with Alt+Ctrl+number and windows with
          # Alt+Shift+number; Sway has a single move-container target,
          # here on the Super variants.
          (lib.listToAttrs (map (n: lib.nameValuePair "Mod4+Ctrl+${toString n}" "move container to workspace number ${toString n}") (lib.range 1 9)))
          (lib.listToAttrs (map (n: lib.nameValuePair "Mod4+Shift+${toString n}" "move container to workspace number ${toString n}") (lib.range 1 9)))
        ]);
        startup = [{command = lib.getExe pkgs.mako;}];
      };
      extraConfig = ''
        blur enable
        blur_radius 5
        blur_passes 3
        shadows enable
        shadow_blur_radius 24
        shadow_color #00000066
        default_dim_inactive 0.08

        # Scroll workspaces/columns like the Niri wheel binds.
        bindsym --whole-window Mod4+button4 workspace prev
        bindsym --whole-window Mod4+button5 workspace next
        bindsym --whole-window Alt+Ctrl+button4 move container to workspace prev
        bindsym --whole-window Alt+Ctrl+button5 move container to workspace next
        bindsym --whole-window Mod4+button6 focus left
        bindsym --whole-window Mod4+button7 focus right
        bindsym --whole-window Alt+Ctrl+button6 move left
        bindsym --whole-window Alt+Ctrl+button7 move right
        bindsym --whole-window Alt+Shift+button4 focus left
        bindsym --whole-window Alt+Shift+button5 focus right
        bindsym --whole-window Alt+Ctrl+Shift+button4 move left
        bindsym --whole-window Alt+Ctrl+Shift+button5 move right
      '';
    };

    services.mako = {
      enable = true;
      settings = {
        background-color = "${cyberdeckScheme.palette.base00}ee";
        text-color = cyberdeckScheme.palette.base05;
        border-color = cyberdeckScheme.palette.base0E;
        border-radius = 12;
        default-timeout = 5000;
      };
    };
    services.swayidle = {
      enable = true;
      systemdTargets = ["sway-session.target"];
      events = {
        before-sleep = lockCommand;
        lock = lockCommand;
      };
      timeouts = [
        {
          timeout = 300;
          command = lockCommand;
        }
        {
          timeout = 600;
          command = ''${swayPackage}/bin/swaymsg "output * power off"'';
          resumeCommand = ''${swayPackage}/bin/swaymsg "output * power on"'';
        }
      ];
    };
    systemd.user.services.sway-polkit = {
      Unit = {
        Description = "Polkit authentication agent for SwayFX";
        PartOf = ["sway-session.target"];
        After = ["sway-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = ["sway-session.target"];
    };
  }
