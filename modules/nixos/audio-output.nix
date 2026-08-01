{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.audioOutput;
in {
  options.lucy.audioOutput = {
    enable = lib.mkEnableOption "Audio output switcher (local/remote sink via pactl)";

    name = lib.mkOption {
      type = lib.types.str;
      default = "audio-output";
      description = "Command name for the switcher script";
    };

    remotePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["remote"];
      description = "Patterns to match remote sink (case-insensitive, matches name or description)";
    };

    notify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send desktop notification on sink change";
    };

    installTo = lib.mkOption {
      type = lib.types.path;
      default = "/usr/local/bin";
      description = "Directory to install the script (via systemd-tmpfiles or user profile)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        inherit (cfg) name;
        runtimeInputs = with pkgs; [jq pulseaudio coreutils gnugrep notify-send];
        text = ''
          sinks_json=$(pactl -f json list sinks)

          remote_sink=$(
            printf '%s' "$sinks_json" | jq -r '
              map(select(${lib.concatStringsSep " or " (lib.map (pat: ''((.description // "") | ascii_downcase | contains("${lib.escapeShellArg pat}")) or ((.name // "") | ascii_downcase | contains("${lib.escapeShellArg pat}"))'') cfg.remotePatterns)}))
              | .[0].name // empty
            '
          )

          local_sink=$(
            printf '%s' "$sinks_json" | jq -r '
              map(select((${lib.concatStringsSep " or " (lib.map (pat: ''((.description // "") | ascii_downcase | contains("${lib.escapeShellArg pat}")) or ((.name // "") | ascii_downcase | contains("${lib.escapeShellArg pat}"))'') cfg.remotePatterns)}) | not))
              | .[0].name // empty
            '
          )

          current_sink=$(pactl get-default-sink)

          choose_target() {
            case "''${1:-menu}" in
              remote)
                printf '%s\n' "$remote_sink"
                ;;
              local)
                printf '%s\n' "$local_sink"
                ;;
              status)
                printf 'default: %s\nlocal: %s\nremote: %s\n' "$current_sink" "$local_sink" "$remote_sink"
                exit 0
                ;;
              menu|"")
                if command -v fuzzel >/dev/null 2>&1; then
                  choice=$(printf 'Remote\nLocal\n' | fuzzel --dmenu --prompt 'Audio Output: ' --width 24)
                  case "$choice" in
                    Remote) printf '%s\n' "$remote_sink" ;;
                    Local) printf '%s\n' "$local_sink" ;;
                    *) exit 1 ;;
                  esac
                else
                  printf 'usage: %s [local|remote|status]\n' "$name" >&2
                  exit 1
                fi
                ;;
              *)
                printf 'usage: %s [local|remote|status]\n' "$name" >&2
                exit 1
                ;;
            esac
          }

          target_sink=$(choose_target "''${1:-menu}")

          if [ -z "$target_sink" ]; then
            printf '%s\n' 'Requested sink not found. Inspect with: pactl -f json list sinks | jq -r ".[] | [.name, .description]"' >&2
            exit 1
          fi

          pactl set-default-sink "$target_sink"

          pactl -f json list sink-inputs | jq -r '.[].index' | while read -r input_id; do
            [ -n "$input_id" ] || continue
            pactl move-sink-input "$input_id" "$target_sink" || true
          done

          printf 'Audio output -> %s\n' "$target_sink"

          ${lib.optionalString cfg.notify ''            if command -v notify-send >/dev/null 2>&1; then
                        notify-send "Audio output changed" "$target_sink"
                      fi''}
        '';
      })
    ];
  };
}
