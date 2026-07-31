# Nix-only post-processing for nix-topology's network SVG.
# The fixer is generated from a data spec: every tunable is an attr of
# `spec`, so call sites carry data (no strings); the shell template below
# is the only place literal strings live.
pkgs: let
  inherit (pkgs) lib;
  defaultSpec = {
    minSpacing = 16;
    labelHeight = 12;
    heightPadding = 20;
    labelMarker = "dominant-baseline=\"hanging\"";
    font = "12px JetBrains Mono";
    iconOffset = -9;
    iconPrefix = "M178.6 ";
    iconSuffix = "h8v8h-8z";
  };
in {
  fixNetworkSvg = spec: let
    s = defaultSpec // spec;
    step = s.labelHeight + s.minSpacing;
    contentHeight = s.labelHeight + s.heightPadding;
  in
    pkgs.writeShellApplication {
      name = "fix-network-svg";
      runtimeInputs = [pkgs.gnused pkgs.gawk pkgs.gnugrep pkgs.coreutils];
      text = ''
        set -euo pipefail
        svg="$1"
        [ -w "$svg" ] || { echo "not writable: $svg" >&2; exit 1; }
        adj=$(mktemp)
        trap 'rm -f "$adj"' EXIT

        # Match the opening tag only: nix-topology emits multiline labels
        # (e.g. IPv6 addresses) whose <text> element spans several lines.
        label_re='<text[^>]* y="[0-9.]+"[^>]*${s.labelMarker}[^>]*style="font:${s.font}"[^>]*>'
        labels=$(grep -oE "$label_re" "$svg" || true)
        [ -n "$labels" ] || exit 0

        # Sort labels by y (4th "..."-delimited field), then compute adjusted
        # positions and icon offsets (icons sit iconOffset px from the label).
        # Positions keep the original decimal format (int or n-decimals).
        # Field order: old_y  new_y  old_icon_y  new_icon_y  <label element>
        printf '%s\n' "$labels" \
          | sort -t'"' -k4,4n \
          | awk -v step="${toString step}" -v off="${toString s.iconOffset}" '
              {
                y = $0; sub(/^.* y="/, "", y); sub(/".*/, "", y)
                if (match(y, /\./)) {
                  decimals = length(y) - RSTART
                  val = y
                } else {
                  decimals = 0
                  val = y
                }
                if (NR == 1) cursor = val
                new = (val < cursor) ? cursor : val
                cursor = new + step
                fmt = (decimals == 0) ? "%d" : "%." decimals "f"
                printf fmt "\t" fmt "\t" fmt "\t" fmt "\t%s\n", val, new, val + off, new + off, $0
              }
            ' > "$adj"

        last_new=""
        while IFS=$'\t' read -r old_y new_y old_icon new_icon element; do
          last_new="$new_y"
          [ "$old_y" = "$new_y" ] && continue

          pattern='y="'$old_y'"'
          replacement='y="'$new_y'"'
          fixed=''${element/$pattern/$replacement}
          # Escape sed metacharacters in the replacement string
          fixed=''${fixed//&/\\&}
          sed -i "s|$element|$fixed|" "$svg"
          sed -i "s|${s.iconPrefix}''${old_icon}${s.iconSuffix}|${s.iconPrefix}''${new_icon}${s.iconSuffix}|" "$svg"
        done < "$adj"

        # Grow the root <svg> height if the last label moved past the old height
        new_height=$(awk -v y="$last_new" -v pad="${toString contentHeight}" 'BEGIN { printf "%.3f", y + pad }')
        orig_height=$(grep -oE '<svg[^>]*height="[0-9.]+"' "$svg" | head -n 1 | sed -nE 's/.*height="([0-9.]+)"/\1/p')
        if awk -v h="$new_height" -v o="$orig_height" 'BEGIN { exit !(h > o) }'; then
          sed -i -E "0,/(<svg[^>]*height=\")[0-9.]+\"/s//\1''${new_height}\"/" "$svg"
        fi
      '';
    };
}
