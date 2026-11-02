# Transparent companion over dwlb's right edge: native SNI tray and clock tooltip.
{
  pkgs,
  settings,
  timezone ? null,
}:
let
  inherit (pkgs) lib;
  inherit (settings) colors;
  # Zone 0 is positioned below dwlb's exclusive zone. A non-reserving overlay
  # needs zone -1 so it anchors to the output edge, not the remaining work area.
  # Patch only this companion's package; other Waybar sessions stay unchanged.
  waybar = pkgs.waybar.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/bar.cpp --replace-fail \
        'gtk_layer_set_exclusive_zone(gtk_window, 0);' \
        'gtk_layer_set_exclusive_zone(gtk_window, -1);'
    '';
  });
  config = pkgs.writeText "dwl-scroll-tray.json" (
    builtins.toJSON {
      name = "dwl-scroll-tray";
      layer = "top";
      position = "top";
      width = 0;
      height = 24;
      exclusive = false;
      fixed-center = false;
      spacing = 8;
      modules-right = [
        "tray"
        "clock"
      ];
      tray = {
        icon-size = 16;
        spacing = 8;
        show-passive-items = true;
      };
      clock = {
        format = " {:%H:%M}";
        tooltip-format = "{:%d.%m.%Y}";
      }
      // lib.optionalAttrs (timezone != null) { inherit timezone; };
    }
  );
  style = pkgs.writeText "dwl-scroll-tray.css" ''
    * {
      font-family: "Iosevka", "Symbols Nerd Font Mono", monospace;
      font-size: 13px;
      min-height: 0;
    }
    window#waybar { background: transparent; color: #${colors.focus}; }
    #tray, #clock {
      background: #${colors.root};
      border: 0;
      border-radius: 0;
      padding: 4px 8px;
    }
    #tray > .needs-attention { color: #${colors.urgent}; }
    tooltip {
      background: #${colors.root};
      color: #${colors.focus};
      border: 1px solid #${colors.focus};
    }
  '';
in
pkgs.writeShellScriptBin "dwl-scroll-tray" ''
  exec ${lib.getExe waybar} --config ${config} --style ${style}
''
