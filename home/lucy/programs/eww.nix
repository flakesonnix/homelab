{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  inherit (frameworkLib.render) css;
  theme = frameworkLib.theme.fromStylix config;
  inherit (theme) colors gradient;
  rules = [
    {
      selector = "*";
      declarations = {
        font_family = ''"Inter", sans-serif'';
        font_size = "14px";
        color = colors.base05;
      };
    }
    {
      selector = "window";
      declarations = {background = "transparent";};
    }
    {
      selector = ".sidebar";
      declarations = {
        background = "${colors.base00}ee";
        border = "1px solid ${colors.base02}";
        border_radius = "0 0 0 18px";
        padding = "24px 18px";
        min_width = "320px";
        min_height = "1080px";
        box_shadow = "0 8px 32px rgba(0,0,0,0.4)";
      };
    }
    {
      selector = ".topbar";
      declarations = {
        background = gradient "90deg" ["${colors.base00}f0" "${colors.base01}e8" "${colors.base02}de"];
        border = "1px solid ${colors.base0E}";
        border_radius = "20px";
        padding = "10px 16px";
        min_height = "46px";
        box_shadow = "0 18px 42px rgba(0,0,0,0.45)";
      };
    }
    {
      selector = ".section";
      declarations = {
        margin = "12px 0";
        spacing = "8px";
      };
    }
    {
      selector = ".row";
      declarations = {
        spacing = "10px";
        align_items = "center";
      };
    }
    {
      selector = ".cluster";
      declarations = {
        background = gradient "135deg" [colors.base01 colors.base02];
        border = "1px solid ${colors.base03}";
        border_radius = "14px";
        padding = "6px 12px";
        spacing = "10px";
      };
    }
    {
      selector = ".icon";
      declarations = {
        font_size = "48px";
        color = colors.base0D;
      };
    }
    {
      selector = ".time";
      declarations = {
        font_size = "56px";
        font_weight = "700";
        color = colors.base05;
      };
    }
    {
      selector = ".date";
      declarations = {
        font_size = "16px";
        color = colors.base04;
      };
    }
    {
      selector = ".separator";
      declarations = {
        background = colors.base02;
        min_height = "1px";
        margin = "16px 0";
      };
    }
    {
      selector = ".widget-title";
      declarations = {
        font_size = "13px";
        color = colors.base0C;
        font_weight = "600";
      };
    }
    {
      selector = "scale";
      declarations = {margin = "8px 0";};
    }
    {
      selector = ".ram-scale";
      declarations = {
        background = colors.base02;
        color = colors.base0A;
      };
    }
    {
      selector = ".cpu-scale";
      declarations = {
        background = colors.base02;
        color = colors.base0B;
      };
    }
    {
      selector = ".media-btn";
      declarations = {
        background = colors.base01;
        border = "1px solid ${colors.base02}";
        border_radius = "12px";
        padding = "12px 18px";
        font_size = "20px";
        color = colors.base05;
        margin = "4px";
      };
    }
    {
      selector = ".media-btn:hover";
      declarations = {
        background = colors.base02;
        color = colors.base0D;
      };
    }
    {
      selector = ".power-btn";
      declarations = {
        background = gradient "135deg" ["${colors.base08}88" "${colors.base09}88"];
        border = "1px solid ${colors.base08}";
        border_radius = "12px";
        padding = "14px 24px";
        font_size = "16px";
        font_weight = "600";
        color = colors.base05;
        margin = "8px 0";
      };
    }
    {
      selector = ".power-btn:hover";
      declarations = {
        background = gradient "135deg" [colors.base08 colors.base09];
      };
    }
    {
      selector = ".weather";
      declarations = {
        background = "${colors.base00}cc";
        border = "1px solid ${colors.base02}";
        border_radius = "16px";
        padding = "16px 24px";
      };
    }
    {
      selector = ".weather-icon";
      declarations = {
        font_size = "32px";
        color = colors.base0D;
      };
    }
    {
      selector = ".weather-temp";
      declarations = {
        font_size = "24px";
        font_weight = "600";
        color = colors.base05;
      };
    }
    {
      selector = ".chip";
      declarations = {
        background = gradient "135deg" [colors.base01 colors.base02];
        border = "1px solid ${colors.base03}";
        border_radius = "999px";
        padding = "6px 12px";
        font_size = "13px";
        font_weight = "600";
      };
    }
    {
      selector = ".chip-accent";
      declarations = {
        background = gradient "90deg" [colors.base0E colors.base0D colors.base0C];
        color = colors.base00;
      };
    }
    {
      selector = ".bar-time";
      declarations = {
        font_size = "18px";
        font_weight = "700";
        letter_spacing = "0.08em";
      };
    }
    {
      selector = ".subtle";
      declarations = {
        color = colors.base04;
        font_size = "12px";
      };
    }
    {
      selector = ".launch-btn";
      declarations = {
        background = "transparent";
        border = "1px solid transparent";
        border_radius = "12px";
        padding = "8px 12px";
        font_size = "16px";
        color = colors.base05;
      };
    }
    {
      selector = ".launch-btn:hover";
      declarations = {
        background = gradient "90deg" [colors.base01 colors.base02];
        border = "1px solid ${colors.base0D}";
      };
    }
    {
      selector = ".metric";
      declarations = {
        font_size = "13px";
        font_weight = "600";
      };
    }
  ];
in {
  config = lib.mkIf config.programs.eww.enable {
    home.packages = [pkgs.eww pkgs.curl];

    xdg.configFile."eww/eww.yuck".text = ''
      (defpoll clock_time :interval "1s" "date +'%H:%M'")
      (defpoll clock_date :interval "30s" "date +'%A, %b %d'")
      (defpoll ram_usage :interval "5s" "sh -lc \"free | awk '/Mem:/ {printf \\\"%.0f%%%%\\\", $3/$2 * 100}'\"")
      (defpoll cpu_usage :interval "5s" "sh -lc \"awk 'NR==1{u=$2+$4;t=$2+$3+$4+$5;printf \\\"%.0f%%%%\\\",u/t*100}' /proc/stat\"")
      (defpoll ram_pct :interval "5s" "sh -lc \"free | awk '/Mem:/ {printf \\\"%.0f\\\", $3/$2 * 100}'\"")
      (defpoll cpu_pct :interval "5s" "sh -lc \"awk 'NR==1{u=$2+$4;t=$2+$3+$4+$5;printf \\\"%.0f\\\",u/t*100}' /proc/stat\"")
      (defpoll volume_text :interval "3s" "sh -lc \"wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{if ($3 == \\\"[MUTED]\\\") print \\\"mute\\\"; else printf \\\"%d%%\\\", $2 * 100}'\"")
      (defpoll network_text :interval "10s" "sh -lc \"ssid=\\$(nmcli -t -f active,ssid dev wifi | awk -F: '$1==\\\"yes\\\" {print $2; exit}'); printf '%s' \\\"''${ssid:-offline}\\\"\"")
      (defpoll media_text :interval "3s" "sh -lc \"playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | cut -c1-40 || echo idle\"")
      (defpoll weather_text :interval "1800s" "sh -lc \"curl -fsS 'https://wttr.in/?format=%C+%t' 2>/dev/null || echo offline\"")

      (defwindow topbar
        :geometry (geometry :x "18px" :y "14px" :width "calc(100% - 36px)" :height "52px" :anchor "top center")
        :stacking "dock"
        :exclusive true
        :namespace "topbar"
        :class "eww-topbar"
        (box
          :class "topbar row"
          :space-evenly false
          :hexpand true
          (box
            :class "row"
            :halign "start"
            :hexpand true
            (button :class "launch-btn" :onclick "fuzzel" "󰍉")
            (button :class "launch-btn" :onclick "alacritty" "")
            (button :class "launch-btn" :onclick "firefox" "󰈹")
            (box :class "cluster row"
              (label :class "metric" :text "")
              (label :class "metric" :text cpu_usage)
              (label :class "subtle" :text "󰠋")
              (label :class "metric" :text ram_usage)
            )
          )
          (box
            :orientation "vertical"
            :valign "center"
            (label :class "bar-time" :text clock_time)
            (label :class "subtle" :text clock_date)
          )
          (box
            :class "row"
            :halign "end"
            :hexpand true
            (box :class "chip row"
              (label :text "󰖙")
              (label :class "metric" :text weather_text)
            )
            (box :class "chip row"
              (label :text "󰕾")
              (label :class "metric" :text volume_text)
            )
            (box :class "chip row"
              (label :text "󰤨")
              (label :class "metric" :text network_text)
            )
            (box :class "chip chip-accent row"
              (label :text "󰎆")
              (label :class "metric" :text media_text)
            )
            (button :class "launch-btn" :onclick "wlogout" "⏻")
          )
        )
      )

      (defwindow sidebar
        :geometry (geometry :x "0px" :y "0px" :width "320px" :height "100%" :anchor "top right")
        :stacking "fg"
        :exclusive false
        :namespace "sidebar"
        :class "eww-sidebar"
        (box
          :class "sidebar"
          (box
            :class "section"
            :orientation "vertical"
            (label :text "󰌁" :class "icon")
            (label :text clock_time :class "time")
            (label :text clock_date :class "date")
          )
          (box :class "separator")
          (box
            :class "section"
            :orientation "vertical"
            (label :text "󰠋 RAM" :class "widget-title")
            (scale
              :value ram_pct
              :min 0
              :max 100
              :class "ram-scale"
            )
          )
          (box
            :class "section"
            :orientation "vertical"
            (label :text "󰐎 CPU" :class "widget-title")
            (scale
              :value cpu_pct
              :min 0
              :max 100
              :class "cpu-scale"
            )
          )
          (box :class "separator")
          (box
            :class "section"
            :orientation "vertical"
            (button
              :class "media-btn"
              :onclick "playerctl play-pause"
              "󰏤"
            )
            (button
              :class "media-btn"
              :onclick "playerctl previous"
              "󰙣"
            )
            (button
              :class "media-btn"
              :onclick "playerctl next"
              "󰙢"
            )
          )
          (box :class "separator")
          (box
            :class "section"
            :orientation "vertical"
            (button
              :class "power-btn"
              :onclick "wlogout"
              "󰗼 Logout"
            )
          )
        )
      )
    '';

    xdg.configFile."eww/eww.scss".text = css.renderSheet rules;
  };
}
