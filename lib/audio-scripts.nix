pkgs: let
  inherit (pkgs) lib;
in {
  # PulseAudio/PipeWire sink switcher.
  # remotePatterns: list of strings matched (case-insensitive) against sink
  # name and description to identify the remote sink.
  # The jq filter is generated from the pattern list at eval time.
  mkAudioSwitcher = {
    name ? "audio-output",
    remotePatterns ? ["remote"],
  }: let
    mkContains = pat: ''((.description // "") | ascii_downcase | contains("${pat}")) or ((.name // "") | ascii_downcase | contains("${pat}"))'';
    remoteSelect = lib.concatStringsSep " or " (map mkContains remotePatterns);
  in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [jq pulseaudio];
      text = ''
        sinks_json=$(pactl -f json list sinks)

        remote_sink=$(
          printf '%s' "$sinks_json" | jq -r '
            map(select(${remoteSelect}))
            | .[0].name // empty
          '
        )

        local_sink=$(
          printf '%s' "$sinks_json" | jq -r '
            map(select((${remoteSelect}) | not))
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
                printf 'usage: audio-output [local|remote|status]\n' >&2
                exit 1
              fi
              ;;
            *)
              printf 'usage: audio-output [local|remote|status]\n' >&2
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

        if command -v notify-send >/dev/null 2>&1; then
          notify-send "Audio output changed" "$target_sink"
        fi
      '';
    };
}
