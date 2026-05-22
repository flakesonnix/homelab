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
  config = lib.mkIf config.programs.vesktop.enable {

    home.activation.vesktopWritableSettings = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      settings_dir="$HOME/.config/vesktop/settings"
      settings_file="$settings_dir/settings.json"
      backup_file="$settings_file.hm-backup"

      run mkdir -p "$settings_dir"

      if [ -e "$backup_file" ] && [ ! -L "$backup_file" ]; then
        run rm -f "$backup_file"
      fi

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
