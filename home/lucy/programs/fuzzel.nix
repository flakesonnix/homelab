{
  config,
  lib,
  pkgs,
  ...
}: {
  options.lucy.fuzzel = {
    enable = lib.mkEnableOption "Fuzzel launcher configuration";
  };

  config = lib.mkIf config.lucy.fuzzel.enable {
    programs.fuzzel = {
      enable = true;
      settings = lib.mkForce {
        main = {
          terminal = "alacritty";
          layer = "overlay";
          font = "Inter:size=12";
          icon-theme = "Papirus-Dark";
          width = 46;
          lines = 8;
          horizontal-pad = 18;
          vertical-pad = 14;
          inner-pad = 12;
          prompt = "";
          dpi-aware = "yes";
          show-actions = "yes";
        };
        border = {
          width = 0;
          radius = 18;
        };
        colors = {
          background = "1a1423ee";
          text = "f0d0f5ff";
          prompt = "ffb6c1ff";
          placeholder = "817695ff";
          input = "f0d0f5ff";
          match = "ff69b4ff";
          selection = "2a2436ff";
          selection-text = "ffffffff";
          selection-match = "ffb6c1ff";
          counter = "c678ddff";
          border = "00000000";
        };
      };
    };

    home.packages = [pkgs.inter];
  };
}
