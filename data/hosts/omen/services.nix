{pkgs, ...}: let
  audioOutputApp = pkgs.writeShellApplication {
    name = "audio-output";
    runtimeInputs = [
      pkgs.jq
      pkgs.pulseaudio
    ];
    text = ''
      set -euo pipefail

      sinks_json=$(pactl -f json list sinks)

      remote_sink=$(
        printf '%s' "$sinks_json" | jq -r '
          map(select(((.description // "") | ascii_downcase | contains("p50 speakers")) or ((.description // "") | ascii_downcase | contains("pipebert")) or ((.name // "") | ascii_downcase | contains("remote"))))
          | .[0].name // empty
        '
      )

      local_sink=$(
        printf '%s' "$sinks_json" | jq -r '
          map(select((((.description // "") | ascii_downcase | contains("p50 speakers")) or ((.description // "") | ascii_downcase | contains("pipebert")) or ((.name // "") | ascii_downcase | contains("remote"))) | not))
          | .[0].name // empty
        '
      )

      current_sink=$(pactl get-default-sink)

      choose_target() {
        case "''${1:-menu}" in
          p50|remote)
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
              choice=$(printf 'P50\nLocal\n' | fuzzel --dmenu --prompt 'Audio Output: ' --width 24)
              case "$choice" in
                P50) printf '%s\n' "$remote_sink" ;;
                Local) printf '%s\n' "$local_sink" ;;
                *) exit 1 ;;
              esac
            else
              printf 'usage: audio-output [local|p50|status]\n' >&2
              exit 1
            fi
            ;;
          *)
            printf 'usage: audio-output [local|p50|status]\n' >&2
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
        pactl move-sink-input "$input_id" "$target_sink"
      done

      printf 'Audio output -> %s\n' "$target_sink"

      if command -v notify-send >/dev/null 2>&1; then
        notify-send "Audio output changed" "$target_sink"
      fi
    '';
  };
in {
  # --- sops-nix secrets (uncomment after running `nix run .#setup-sops`) ---
  # lucy.secrets = {
  #   enable = true;
  #   sopsFile = ../../../hosts/omen/secrets.yaml;
  # };

  lucy.hostPackages = [audioOutputApp];

  services.asteriskLocal = {
    enable = false;
    # secrets.enable = true;  # Enable with sops-nix templated config

    # Keep empty in repo; set locally (ideally via sops-nix template).
    openFirewall = true;
    phones = {};
    extraExtensions = "";
  };

  # The receiver is currently reachable on omen via the `p50` host mapping.
  hq.audio.streamTo = "p50";

  programs.noisetorch.enable = true;

  # nix-serve-ng → LAN binary cache for p50/mireo
  # Manual service (nixpkgs nix-serve module stale, crashes as nix-serve user)
  systemd.services.nix-serve = {
    description = "nix-serve-ng binary cache server";
    after = ["network.target" "nix-daemon.service"];
    wantedBy = ["multi-user.target"];
    environment.NIX_REMOTE = "daemon";
    serviceConfig = {
      ExecStart = "${pkgs.nix-serve-ng}/bin/nix-serve --listen 0.0.0.0:5000";
      User = "root";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  networking.firewall.allowedTCPPorts = [5000];
}
