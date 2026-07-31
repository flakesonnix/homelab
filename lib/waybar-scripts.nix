pkgs: {
  mkMediaPopup = pkgs.writeShellApplication {
    name = "waybar-media-popup";
    runtimeInputs = with pkgs; [playerctl curl libnotify];
    text = ''
      title=$(playerctl metadata title 2>/dev/null)
      artist=$(playerctl metadata artist 2>/dev/null)
      album=$(playerctl metadata album 2>/dev/null)
      art_url=$(playerctl metadata mpris:artUrl 2>/dev/null)

      [ -z "$title" ] && exit 0

      body=""
      [ -n "$artist" ] && body="$artist"
      [ -n "$album" ] && body="$body\n$album"

      art_file=""
      if [ -n "$art_url" ]; then
        case "$art_url" in
          file://*)
            art_file="''${art_url#file://}"
            ;;
          http*)
            art_file="/tmp/waybar-media-art.jpg"
            curl -sf "$art_url" -o "$art_file" 2>/dev/null
            ;;
        esac
      fi

      icon_arg=""
      [ -n "$art_file" ] && [ -f "$art_file" ] && icon_arg="-i $art_file"

      # shellcheck disable=SC2086
      notify-send $icon_arg \
        -t 4000 \
        -h string:x-canonical-private-synchronous:media-popup \
        "$title" "$(printf '%b' "$body")"
    '';
  };

  mkPlayerPicker = pkgs.writeShellApplication {
    name = "waybar-player-picker";
    runtimeInputs = with pkgs; [playerctl fuzzel];
    text = ''
      players=$(playerctl -l 2>/dev/null)
      count=$(printf '%s\n' "$players" | grep -c . || echo 0)

      if [ "$count" -le 1 ]; then
        playerctl next
      else
        selected=$(printf '%s\n' "$players" | fuzzel --dmenu --prompt "Player: " --width 30)
        [ -n "$selected" ] && playerctl -p "$selected" play-pause
      fi
    '';
  };

  mkNotifCounter = {
    icons ? {
      active = "󱅫";
      inactive = "󰂚";
    },
  }:
    pkgs.writeShellApplication {
      name = "waybar-notifications";
      runtimeInputs = with pkgs; [mako jq];
      text = ''
        output=$(makoctl list 2>&1)
        if printf '%s' "$output" | grep -q "DBus\|does not exist\|Error"; then
          printf '{"text":"${icons.inactive}","class":"inactive","tooltip":"No notifications"}\n'
          exit 0
        fi
        count=$(printf '%s' "$output" | jq -r '[.data[].notifications | length] | add // 0' 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
          printf '{"text":"${icons.active} %s","class":"active","tooltip":"%s notifications"}\n' "$count" "$count"
        else
          printf '{"text":"${icons.inactive}","class":"inactive","tooltip":"No notifications"}\n'
        fi
      '';
    };
}
