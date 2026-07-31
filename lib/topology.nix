# Nix-only post-processing for nix-topology's network SVG.
#
# The fixer logic is a pure Nix function (lib/topology-fixer.nix, builtins
# only) that maps an SVG string to the fixed SVG string. Every tunable is an
# attr of `spec`; call sites carry data, no shell strings.
#
# The generated SVG only exists as a store path at build time, so the fix is
# applied by evaluating the pure function with `nix eval --file` inside a
# thin runner; the shell is plumbing only (mktemp/mv), no fixer logic.
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
  # Pure: fix the given SVG string with the given spec.
  fixNetworkSvg = spec: svg:
    (import ./topology-fixer.nix {
      inherit svg;
      spec = defaultSpec // spec;
    });

  # Build-time runner: fixes a generated SVG file in place via `nix eval`.
  # The fixer runs as pure Nix; the shell is plumbing only (mv/mktemp).
  fixNetworkSvgApp = spec: let
    fixer = pkgs.writeText "topology-fixer.nix" (builtins.readFile ./topology-fixer.nix);
    expr = pkgs.writeText "fix-network-svg.nix" ''
      (import ${fixer}) {
        spec = builtins.fromJSON '''${builtins.toJSON (defaultSpec // spec)}''';
        svg = builtins.readFile (builtins.getEnv "SVG_PATH");
      }
    '';
  in
    pkgs.writeShellApplication {
      name = "fix-network-svg";
      runtimeInputs = [pkgs.nix pkgs.coreutils];
      text = ''
        set -euo pipefail
        svg="$(realpath "$1")"
        [ -w "$svg" ] || { echo "not writable: $svg" >&2; exit 1; }
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT
        SVG_PATH="$svg" NIX_STATE_DIR="$(mktemp -d)" \
          nix --extra-experimental-features nix-command eval --impure --raw \
          --file ${expr} > "$tmp"
        mv -f "$tmp" "$svg"
      '';
    };
}
