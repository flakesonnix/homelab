{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  inherit (frameworkLib.render) css;
  colors = config.lib.stylix.colors.withHashtag;
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
      selector = ".section";
      declarations = {
        margin = "12px 0";
        spacing = "8px";
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
        background = "linear-gradient(135deg, ${colors.base08}88, ${colors.base09}88)";
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
        background = "linear-gradient(135deg, ${colors.base08}, ${colors.base09})";
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
  ];
in {
  config = lib.mkIf config.programs.eww.enable {
    home.packages = [pkgs.eww];

    xdg.configFile."eww/eww.yuck".text = ''
      (defwindow sidebar
        :anchor "top right"
        :windowtype "layer"
        :layer "top"
        :exclusive true
        :reserve "top"
        :width 320
        :height 1080
        :class "eww-sidebar"
        (box
          :class "sidebar"
          (box
            :class "section"
            :orientation "vertical"
            (label :text "󰌁" :class "icon")
            (label :text "$(date +'%H:%M')" :class "time")
            (label :text "$(date +'%A, %b %d')" :class "date")
          )
          (box :class "separator")
          (box
            :class "section"
            :orientation "vertical"
            (label :text "󰠋 RAM" :class "widget-title")
            (scale
              :value "$(free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}')"
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
              :value "$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1 | awk '{printf \"%.0f\", $1}')"
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

      (defwindow weather
        :anchor "top center"
        :windowtype "layer"
        :layer "top"
        :width 200
        :height 100
        (box
          :class "weather"
          (label :text "󰖞" :class "weather-icon")
          (label :text "22°C" :class "weather-temp")
        )
      )
    '';

    xdg.configFile."eww/eww.scss".text = css.renderSheet rules;
  };
}
