{ niri-flake ? null }:

{ lib, config, pkgs, ... }:

let
  inherit (lib) mkIf mkOption types;
in
{
  options.lucy.niri = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable niri window manager configuration";
    };
  };

  config = mkIf config.lucy.niri.enable {
    imports = [
      niri-flake.homeModules.config
    ];

    programs.niri = {
      enable = true;

      settings = {
        binds = {
          "Mod+T" = {
            action.spawn = "alacritty";
          };
          "Mod+D" = {
            action.spawn = "fuzzel";
          };
          "Mod+Shift+Slash" = {
            action.show-hotkey-overlay = null;
          };
          "Mod+Q" = {
            action.close-window = null;
          };
          "Mod+Left" = {
            action.focus-column-left = null;
          };
          "Mod+Down" = {
            action.focus-window-down = null;
          };
          "Mod+Up" = {
            action.focus-window-up = null;
          };
          "Mod+Right" = {
            action.focus-column-right = null;
          };
          "Mod+H" = {
            action.focus-column-left = null;
          };
          "Mod+J" = {
            action.focus-window-down = null;
          };
          "Mod+K" = {
            action.focus-window-up = null;
          };
          "Mod+L" = {
            action.focus-column-right = null;
          };
          "Mod+Ctrl+Left" = {
            action.move-column-left = null;
          };
          "Mod+Ctrl+Down" = {
            action.move-window-down = null;
          };
          "Mod+Ctrl+Up" = {
            action.move-window-up = null;
          };
          "Mod+Ctrl+Right" = {
            action.move-column-right = null;
          };
          "Mod+Ctrl+H" = {
            action.move-column-left = null;
          };
          "Mod+Ctrl+J" = {
            action.move-window-down = null;
          };
          "Mod+Ctrl+K" = {
            action.move-window-up = null;
          };
          "Mod+Ctrl+L" = {
            action.move-column-right = null;
          };
          "Mod+Page_Down" = {
            action.focus-workspace-down = null;
          };
          "Mod+Page_Up" = {
            action.focus-workspace-up = null;
          };
          "Mod+U" = {
            action.focus-workspace-down = null;
          };
          "Mod+I" = {
            action.focus-workspace-up = null;
          };
          "Mod+Ctrl+Page_Down" = {
            action.move-column-to-workspace-down = null;
          };
          "Mod+Ctrl+Page_Up" = {
            action.move-column-to-workspace-up = null;
          };
          "Mod+Ctrl+U" = {
            action.move-column-to-workspace-down = null;
          };
          "Mod+Ctrl+I" = {
            action.move-column-to-workspace-up = null;
          };
          "Mod+Shift+Page_Down" = {
            action.move-workspace-down = null;
          };
          "Mod+Shift+Page_Up" = {
            action.move-workspace-up = null;
          };
          "Mod+Shift+U" = {
            action.move-workspace-down = null;
          };
          "Mod+Shift+I" = {
            action.move-workspace-up = null;
          };
          "Mod+1" = {
            action.focus-workspace = 1;
          };
          "Mod+2" = {
            action.focus-workspace = 2;
          };
          "Mod+3" = {
            action.focus-workspace = 3;
          };
          "Mod+4" = {
            action.focus-workspace = 4;
          };
          "Mod+5" = {
            action.focus-workspace = 5;
          };
          "Mod+6" = {
            action.focus-workspace = 6;
          };
          "Mod+7" = {
            action.focus-workspace = 7;
          };
          "Mod+8" = {
            action.focus-workspace = 8;
          };
          "Mod+9" = {
            action.focus-workspace = 9;
          };
          "Mod+Ctrl+1" = {
            action.move-column-to-workspace = 1;
          };
          "Mod+Ctrl+2" = {
            action.move-column-to-workspace = 2;
          };
          "Mod+Ctrl+3" = {
            action.move-column-to-workspace = 3;
          };
          "Mod+Ctrl+4" = {
            action.move-column-to-workspace = 4;
          };
          "Mod+Ctrl+5" = {
            action.move-column-to-workspace = 5;
          };
          "Mod+Ctrl+6" = {
            action.move-column-to-workspace = 6;
          };
          "Mod+Ctrl+7" = {
            action.move-column-to-workspace = 7;
          };
          "Mod+Ctrl+8" = {
            action.move-column-to-workspace = 8;
          };
          "Mod+Ctrl+9" = {
            action.move-column-to-workspace = 9;
          };
          "Mod+Comma" = {
            action.consume-window-into-column = null;
          };
          "Mod+Period" = {
            action.expel-window-from-column = null;
          };
          "Mod+R" = {
            action.switch-preset-column-width = null;
          };
          "Mod+F" = {
            action.maximize-column = null;
          };
          "Mod+Shift+F" = {
            action.fullscreen-window = null;
          };
          "Mod+C" = {
            action.center-column = null;
          };
          "Mod+Minus" = {
            action.set-column-width = "-10%";
          };
          "Mod+Equal" = {
            action.set-column-width = "+10%";
          };
          "Mod+Shift+Minus" = {
            action.set-window-height = "-10%";
          };
          "Mod+Shift+Equal" = {
            action.set-window-height = "+10%";
          };
          "Print" = {
            action.screenshot = null;
          };
          "Ctrl+Print" = {
            action.screenshot-screen = null;
          };
          "Alt+Print" = {
            action.screenshot-window = null;
          };
          "Mod+Shift+E" = {
            action.quit.skip-confirmation = true;
          };
          "Mod+Shift+P" = {
            action.power-off-monitors = null;
          };
        };

        input.keyboard.xkb = {
          layout = "us";
        };

        input.touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };
    };
  };
}
