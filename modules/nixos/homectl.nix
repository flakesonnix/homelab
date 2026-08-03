{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.lucy.homectl;
in {
  options = {
    lucy.homectl = {
      enable = mkEnableOption "homectl control plane";

      role = mkOption {
        type = types.enum ["api" "agent" "cli"];
        description = "homectl role of this host (api runs the server)";
      };

      api = {
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "homectl-api server binary (set by the flake)";
        };
        port = mkOption {
          type = types.port;
          default = 8443;
          description = "API listen port";
        };
        artifactsDir = mkOption {
          type = types.path;
          description = "Directory with Nix-generated manifest.json and ui.json";
        };
        webDir = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Built homectl-web SPA directory (served at /)";
        };
        proxy = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              target = mkOption {
                type = types.str;
                description = "Upstream URL, e.g. http://10.8.0.2:3000";
              };
              subPath = mkOption {
                type = types.bool;
                default = false;
                description = "App serves under /apps/<name> (e.g. Grafana)";
              };
            };
          });
          default = {};
          description = "Reverse-proxy routes mounted at /apps/<name>";
        };
      };

      agent = {
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "homectl-agent binary (set by the flake)";
        };
        endpoint = mkOption {
          type = types.str;
          default = "wss://homectl.lan:8443/api/v1/ws";
          description = "API WebSocket endpoint this agent connects to";
        };
        tokenFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File with the agent bearer token (sops-managed, mode 0600)";
        };
        plugins = mkOption {
          type = types.listOf types.str;
          default = ["systemd" "journal" "metrics"];
          description = "Enabled agent plugins (selection is declarative, execution is Go)";
        };
        filesRoots = mkOption {
          type = types.listOf types.path;
          default = [];
          description = "Path allowlist for the files plugin";
        };
        terminalUser = mkOption {
          type = types.str;
          default = "lucy";
          description = "User for browser terminal sessions";
        };
      };

      ui = {
        navigation = mkOption {
          type = types.listOf (types.submodule {
            options = {
              label = mkOption {type = types.str;};
              path = mkOption {type = types.str;};
              page = mkOption {type = types.str;};
            };
          });
          default = [];
          description = "Extra navigation entries merged into the generated ui.json";
        };
        dashboardWidgets = mkOption {
          type = types.listOf (types.submodule {
            options = {
              type = mkOption {type = types.str;};
              host = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              dataSource = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              refreshMs = mkOption {
                type = types.nullOr types.ints.positive;
                default = null;
              };
              config = mkOption {
                type = types.attrs;
                default = {};
              };
            };
          });
          default = [];
          description = "Extra dashboard widgets merged into ui.json";
        };
        pages = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              enabled = mkOption {
                type = types.bool;
                default = true;
              };
            };
          });
          default = {};
          description = "Per-page feature toggles (page exists iff enabled)";
        };
      };

      rbac = mkOption {
        type = types.listOf (types.submodule {
          options = {
            role = mkOption {type = types.str;};
            action = mkOption {type = types.str;};
            resource = mkOption {type = types.str;};
          };
        });
        default = [];
        description = "Permission policy (role, action, resource); enforced by Go, declared here";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.role == "api" && cfg.api.package != null) {
        systemd.services.homectl-api = {
          description = "homectl control-plane API";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          serviceConfig = {
            ExecStart = lib.concatStringsSep " " (
              [
                "${cfg.api.package}/bin/homectl-api"
                "--manifest"
                "${toString cfg.api.artifactsDir}/manifest.json"
                "--ui"
                "${toString cfg.api.artifactsDir}/ui.json"
              ]
              ++ lib.optional (cfg.api.webDir != null) "--web ${toString cfg.api.webDir}"
            );
            Restart = "on-failure";
            DynamicUser = true;
            StateDirectory = "homectl";
          };
        };
      })
      (lib.mkIf (cfg.role == "agent" && cfg.agent.package != null) {
        systemd.services.homectl-agent = {
          description = "homectl agent";
          wantedBy = ["multi-user.target"];
          after = ["network-online.target"];
          serviceConfig = {
            ExecStart = "${cfg.agent.package}/bin/homectl-agent";
            Restart = "on-failure";
            DynamicUser = true;
          };
        };
      })
    ]
  );
}
