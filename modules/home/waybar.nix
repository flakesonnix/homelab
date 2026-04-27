{
  lib,
  config,
  pkgs,
  ...
}: let
  toCSS = rules: let
    renderBlock = sel: attrs: let
      renderDecl = name: val: let
        dashify = s: lib.replaceStrings ["_"] ["-"] s;
        toVal = v:
          if lib.isString v
          then v
          else if lib.isList v
          then lib.concatStringsSep ", " v
          else toString v;
      in "${
        if lib.hasPrefix "-" name
        then name
        else dashify name
      }: ${toVal val};";
    in "${sel} {\n${lib.concatStringsSep "\n" (lib.mapAttrsToList renderDecl attrs)}\n}";
    fold = acc: rule:
      if lib.isAttrs rule
      then acc + (lib.concatStringsSep "\n" (lib.mapAttrsToList renderBlock rule)) + "\n"
      else if lib.isString rule
      then acc + rule + "\n"
      else acc;
  in
    builtins.foldl' fold "" rules;

  waybarStyle = toCSS [
    {
      "*" = {
        font_family = ["Hack" "monospace"];
        font_size = "13px";
        min_height = "0";
      };
    }
    {
      "window#waybar" = {
        background = "rgba(255, 255, 255, 0.06)";
        color = "#c8c8d8";
      };
    }
    {
      "window#waybar.dock" = {
        background = "rgba(255, 255, 255, 0.06)";
        color = "#c8c8d8";
      };
    }
    {
      "#workspaces" = {
        margin_left = "0";
        padding = "0 4px";
      };
    }
    {
      "#workspaces button" = {
        color = "#8888a0";
        padding = "3px 10px";
        margin = "1px";
        border_radius = "10px";
        transition = "all 150ms ease";
      };
    }
    {
      "#workspaces button.active" = {
        color = "#ffffff";
        background = "rgba(255, 255, 255, 0.14)";
        box_shadow = "0 2px 8px rgba(0, 0, 0, 0.16)";
      };
    }
    {"#workspaces button.urgent" = {background = "rgba(160, 160, 255, 0.2)";};}
    {
      "#clock" = {
        color = "#e0e0f0";
        font_weight = "500";
        padding = "0 16px";
        letter_spacing = "0.02em";
      };
    }
    {"#battery" = {color = "#c8c8d8";};}
    {"#battery.charging" = {color = "#80ff80";};}
    {"#battery.warning" = {color = "#ffb86c";};}
    {"#battery.critical" = {color = "#ff5555";};}
    {"#cpu, #memory" = {color = "#9090b0";};}
    {"#cpu.warning, #memory.warning" = {color = "#ffb86c";};}
    {"#cpu.critical, #memory.critical" = {color = "#ff5555";};}
    {
      "#custom-power" = {
        color = "#8080a0";
        min_width = "20px";
        padding = "0 10px";
      };
    }
    {
      "#custom-power:hover" = {
        color = "#ff5555";
        background = "rgba(255, 85, 85, 0.1)";
      };
    }
    {"#network" = {color = "#c8c8d8";};}
    {"#network.disconnected" = {color = "#ff5555";};}
    {"#pulseaudio" = {color = "#c8c8d8";};}
    {"#pulseaudio.muted" = {color = "#505060";};}
    {
      "tooltip" = {
        background = "rgba(26, 26, 46, 0.92)";
        color = "#c8c8d8";
        border = "1px solid rgba(255, 255, 255, 0.08)";
        border_radius = "10px";
        padding = "6px 10px";
        box_shadow = "0 8px 24px rgba(0, 0, 0, 0.3)";
      };
    }
    {"tooltip label" = {color = "#a8a8c0";};}
  ];
in {
  options.lucy.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.lucy.waybar.enable {
    home.packages = [pkgs.siji];
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "top";
          position = "top";
          height = 38;
          margin-top = 10;
          margin-left = 12;
          margin-right = 12;
          modules-left = ["niri/workspaces"];
          modules-center = ["clock"];
          modules-right = ["network" "pulseaudio" "battery" "cpu" "memory" "custom/power"];
        }
      ];
    };
    xdg.configFile."waybar/style.css" = lib.mkForce {source = pkgs.writeText "waybar-style.css" waybarStyle;};
  };
}
