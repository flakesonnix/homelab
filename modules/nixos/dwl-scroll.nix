{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lucy.dwlScroll;

  # Import the typed settings interface and defaults from pkgs/dwl-scroll/config.nix
  dwlScrollSettings = import ../../pkgs/dwl-scroll/config.nix { inherit lib; };

  # Derived package based on the selected settings. Override configH to supply a
  # complete raw C header instead of using the Nix settings interface.
  settingsPackage = pkgs.callPackage ../../pkgs/dwl-scroll {
    # The package resolves null commands to absolute executable store paths.
    settings = cfg.settings;
  };
  bar = import ../../pkgs/dwl-scroll/bar.nix {
    inherit pkgs;
    settings = cfg.settings;
  };
  tray = import ../../pkgs/dwl-scroll/tray.nix {
    inherit pkgs;
    settings = cfg.settings;
    timezone = config.time.timeZone;
  };
  status = pkgs.writeShellScript "dwl-scroll-status" ''
    exec ${lib.getExe pkgs.python3} ${../../pkgs/dwl-scroll/status.py} \
      --dwlb ${lib.getExe pkgs.dwlb} \
      --busctl ${config.systemd.package}/bin/busctl \
      ${lib.optionalString (lib.elem "nvidia" config.services.xserver.videoDrivers) "--nvidia-smi ${lib.getExe' config.hardware.nvidia.package "nvidia-smi"}"}
  '';
  sessionService = {
    wantedBy = [ "dwl-scroll-session.target" ];
    requisite = [ "dwl-scroll-session.target" ];
    partOf = [ "dwl-scroll-session.target" ];
    after = [ "dwl-scroll-session.target" ];
    unitConfig.ConditionEnvironment = [
      "XDG_CURRENT_DESKTOP=dwl-scroll"
      "WAYLAND_DISPLAY"
    ];
  };

  # Session wrapper script used by the GDM session entry.
  startup = pkgs.writeShellScript "dwl-scroll-startup" ''
    # dwl invokes -s only after creating its Wayland socket (and Xwayland).
    ${config.systemd.package}/bin/systemctl --user import-environment \
      WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE ''${DISPLAY:+DISPLAY}
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
      WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE ''${DISPLAY:+DISPLAY}
    ${config.systemd.package}/bin/systemctl --user start dwl-scroll-session.target
    ${cfg.startupCommands}
    # dwl's -s pipe supplies tags, layout and title on stdin. No IPC patch needed.
    exec ${lib.getExe bar}
  '';
  session = pkgs.writeShellScript "dwl-scroll-session" ''
    export XDG_CURRENT_DESKTOP=dwl-scroll
    export XDG_SESSION_TYPE=wayland
    ${cfg.extraSessionCommands}
    cleanup() {
      ${config.systemd.package}/bin/systemctl --user stop dwl-scroll-session.target
      ${config.systemd.package}/bin/systemctl --user unset-environment \
        WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    }
    trap cleanup EXIT
    ${lib.getExe cfg.package} -s ${startup} &
    compositor=$!
    trap 'kill -TERM "$compositor" 2>/dev/null; wait "$compositor"' HUP INT TERM
    wait "$compositor"
  '';
  sessionPackage =
    pkgs.runCommand "dwl-scroll-session"
      {
        passthru.providedSessions = [ "dwl-scroll" ];
      }
      ''
        mkdir -p "$out/share/wayland-sessions"
        cat > "$out/share/wayland-sessions/dwl-scroll.desktop" <<EOF
        [Desktop Entry]
        Name=dwl-scroll
        Comment=Upstream dwl with persistent scrolling columns
        Exec=${session}
        Type=Application
        DesktopNames=dwl-scroll
        EOF
      '';
in
{
  options.lucy.dwlScroll = {
    enable = lib.mkEnableOption "the opt-in upstream dwl scrolling session";

    # Typed settings for configuring dwl-scroll at build time. This mirrors the
    # static `pkgs/dwl-scroll/config.h`; the render function validates values and
    # produces the complete C header.
    settings = lib.mkOption {
      type = lib.types.submodule { options = dwlScrollSettings.options; };
      default = { };
      description = ''
        Settings that drive the dwl-scroll compositor.
        Use this attrset to configure keybindings, gaps, commands, etc.
        (The defaults match the static config.h in the repository.)
      '';
    };

    # Derived package based on the selected settings. Override configH to supply a
    # complete raw C header instead of using the Nix settings interface.
    package = lib.mkOption {
      type = lib.types.package;
      default = settingsPackage;
      defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/dwl-scroll { settings = config.lucy.dwlScroll.settings; }";
      description = "dwl-scroll package; override configH to supply a complete C header.";
    };

    extraSessionCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell commands before dwl starts, for session-local environment variables.";
    };
    startupCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell commands after WAYLAND_DISPLAY is available. Background long-running commands.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.settings.discordRpc.enable || cfg.settings.discordRpc.clientId != null;
        message = "dwl-scroll Discord RPC requires settings.discordRpc.clientId (public application ID, not a token).";
      }
    ];
    # Do not enable programs.dwl, replace pkgs.dwl, select a greeter, or
    # change the host's default session. Vanilla dwl can coexist with this.
    environment.systemPackages = [
      cfg.package
      pkgs.dwlb
      pkgs.networkmanagerapplet
    ];
    fonts.packages = [
      pkgs.iosevka
      pkgs.nerd-fonts.symbols-only
    ];
    services.displayManager.sessionPackages = [ sessionPackage ];
    services.graphical-desktop.enable = true;
    hardware.graphics.enable = true;
    security.polkit.enable = true;
    security.pam.services.swaylock = { };

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.dwl-scroll = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };

    systemd.user.targets.dwl-scroll-session = {
      description = "dwl-scroll graphical session";
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
    };
    systemd.user.services.dwl-scroll-polkit = {
      description = "PolicyKit authentication agent for dwl-scroll";
      wantedBy = [ "dwl-scroll-session.target" ];
      requisite = [ "dwl-scroll-session.target" ];
      partOf = [ "dwl-scroll-session.target" ];
      after = [ "dwl-scroll-session.target" ];
      unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=dwl-scroll";
      serviceConfig.ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    };
    systemd.user.services.dwl-scroll-status = sessionService // {
      description = "dwlb battery and system metrics";
      serviceConfig = {
        ExecStart = status;
        Restart = "on-failure";
      };
    };
    systemd.user.services.dwl-scroll-tray = sessionService // {
      description = "Clock and tray overlay for dwl-scroll";
      serviceConfig = {
        ExecStart = lib.getExe tray;
        Restart = "on-failure";
      };
    };
    systemd.user.services.dwl-scroll-nm-applet = lib.mkIf config.networking.networkmanager.enable (
      sessionService
      // {
        description = "NetworkManager tray controls for dwl-scroll";
        after = sessionService.after ++ [ "dwl-scroll-tray.service" ];
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.networkmanagerapplet} --indicator";
          Restart = "on-failure";
        };
      }
    );
  };
}
