{
  lib,
  config,
  ...
}: let
  settingsJson = builtins.toJSON {
    arRPC = true;
    discordBranch = "stable";
    customTitleBar = true;
    minimizeToTray = true;
    splashBackground = config.lib.stylix.colors.withHashtag.base00;
    splashColor = config.lib.stylix.colors.withHashtag.base0E;
    staticTitle = true;
    theme = "dark";
  };
in {
  options.lucy.vesktop.enable = lib.mkEnableOption "Vesktop (Discord client)";

  config = lib.mkIf config.lucy.vesktop.enable {
    programs.vesktop.enable = true;

    home.activation.vesktopWritableSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      settings_dir="$HOME/.config/vesktop/settings"
      settings_file="$settings_dir/settings.json"

      run mkdir -p "$settings_dir"

      if [ -L "$settings_file" ]; then
        target=$(readlink -f "$settings_file" || true)
        case "$target" in
          /nix/store/*) run rm -f "$settings_file" ;;
        esac
      fi

      if [ ! -e "$settings_file" ]; then
        run tee "$settings_file" >/dev/null <<'EOF'
${settingsJson}
EOF
      fi
    '';
  };
}
