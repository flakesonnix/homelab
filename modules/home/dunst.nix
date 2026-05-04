{
  lib,
  config,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
in {
  options.programs.dunst.enable = lib.mkEnableOption "Dunst notification daemon";

  config = lib.mkIf config.programs.dunst.enable {
    home.packages = [pkgs.dunst];

    xdg.configFile."dunst/dunstrc".text = ''
      [global]
      monitor = 0
      follow = mouse
      geometry = "300x5-18+18"
      progress_bar = true
      progress_bar_height = 10
      progress_bar_frame_width = 1
      progress_bar_min_width = 150
      alignment = left
      icon_position = left
      max_icon_size = 48
      word_wrap = true
      ignore_newline = no
      stack_duplicates = true
      hide_duplicate_count = false
      show_age_threshold = 60
      force_display_urgency = 0
      idle_threshold = 120
      font = Inter 12
      line_height = 0
      separator_height = 1
      padding = 16
      horizontal_padding = 16
      text_icon_padding = 12
      border = 1
      border_radius = 18
      frame_width = 0
      sort = yes
      indicate_hidden = yes
      transparency = 10
      show_indicators = yes
      separator_color = auto
      startup_notification = false
      dmenu = /usr/bin/dmenu -p dunst:
      browser = /usr/bin/firefox -new-tab
      always_run_script = true
      title = Dunst
      class = Dunst
      corner_radius = 18
      ignore_dbusclose = false

      [frame]
      width = 0
      color = "${colors.base00}"

      [section]
      show_age = true
      stack_duplicates = true

      [experimental]
      per_monitor_dbus = false

      [urgency_low]
      background = "${colors.base00}e6"
      foreground = "${colors.base05}"
      timeout = 3000
      border_color = "${colors.base0D}66"

      [urgency_normal]
      background = "${colors.base00}e6"
      foreground = "${colors.base05}"
      timeout = 5000
      border_color = "${colors.base0E}99"

      [urgency_critical]
      background = "${colors.base08}ee"
      foreground = "${colors.base05}"
      timeout = 0
      border_color = "${colors.base08}cc"
    '';

    systemd.user.services.dunst = lib.mkIf (config.programs.niri.enable or false) {
      Unit = {
        Description = "Dunst notification daemon";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = "${pkgs.dunst}/bin/dunst";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
