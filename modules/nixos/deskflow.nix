{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.hq.deskflow;

  # generate section-based server config
  #   section: options
  #       heartbeat = 5000
  #       protocol = barrier
  #   end
  serverConf = pkgs.writeText "deskflow-server.conf" (let
    screens = builtins.attrNames cfg.screenLayout;
    links = lib.concatStringsSep "\n" (lib.flatten (lib.mapAttrsToList (
        name: dirs:
          ["    ${name}:"]
          ++ lib.optional (dirs.left != null) "        left = ${dirs.left}"
          ++ lib.optional (dirs.right != null) "        right = ${dirs.right}"
          ++ lib.optional (dirs.up != null) "        up = ${dirs.up}"
          ++ lib.optional (dirs.down != null) "        down = ${dirs.down}"
      )
      cfg.screenLayout));
  in ''
    section: screens
    ${lib.concatStringsSep "\n" (map (s: "    ${s}:") screens)}
    end

    section: aliases
    end

    section: links
    ${links}
    end

    section: options
        heartbeat = 5000
        protocol = barrier
        relativeMouseMoves = false
        win32KeepForeground = false
        disableLockToScreen = false
        clipboardSharing = true
        clipboardSharingSize = 3584
        switchCorners = none +top-left +top-right +bottom-left +bottom-right
        switchCornerSize = 0
    end
  '');

  # INI settings file for deskflow-core --settings
  settingsIni = pkgs.writeText "deskflow-settings.ini" (
    if cfg.role == "server"
    then ''
      [core]
      coreMode=2
      screenName=${config.networking.hostName}
      port=24800

      [server]
      externalConfig=true
      externalConfigFile=/etc/deskflow/server.conf
    ''
    else ''
      [core]
      coreMode=1
      screenName=${config.networking.hostName}
      port=24800

      [client]
      remoteHost=${cfg.serverAddress}
    ''
  );
in {
  options.hq.deskflow = {
    enable = lib.mkEnableOption "Deskflow keyboard/mouse sharing";

    role = lib.mkOption {
      type = lib.types.enum ["server" "client"];
      default = "client";
      description = "Role: server (shares its KBM) or client (remote controlled)";
    };

    serverAddress = lib.mkOption {
      type = lib.types.str;
      default = "x270";
      description = "Server hostname/IP for client mode";
    };

    screenLayout = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          left = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          right = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          up = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          down = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      });
      default = {};
      example = {
        x270 = {};
      };
      description = "Deskflow server screen layout map";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.deskflow];

    environment.etc =
      {
        "deskflow/settings.ini".source = settingsIni;
      }
      // lib.optionalAttrs (cfg.role == "server") {
        "deskflow/server.conf".source = serverConf;
      };

    systemd.services.deskflow = {
      description = "Deskflow ${cfg.role}";
      documentation = ["https://github.com/deskflow/deskflow"];
      wantedBy = ["graphical.target"];
      after = ["network.target" "graphical.target"];
      serviceConfig = {
        User = "lucy";
        Type = "simple";
        ExecStart = "${pkgs.deskflow}/bin/deskflow-core ${cfg.role} --settings /etc/deskflow/settings.ini";
        Restart = "on-failure";
        RestartSec = "10";
        Environment = [
          "DISPLAY=:0"
          "WAYLAND_DISPLAY=wayland-1"
          "XDG_RUNTIME_DIR=/run/user/1000"
        ];
      };
    };
  };
}
