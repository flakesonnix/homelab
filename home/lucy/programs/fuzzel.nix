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
          font = "Inter:size=13";
          icon-theme = "Papirus-Dark";
          width = 46;
          lines = 8;
          horizontal-pad = 22;
          vertical-pad = 18;
          inner-pad = 16;
          prompt = "search >  ";
          dpi-aware = "yes";
          show-actions = "yes";
        };
        border = {
          width = 1;
          radius = 22;
        };
        colors = {
          background = "161626ee";
          text = "f7f4ffff";
          prompt = "ffd4e9ff";
          placeholder = "9d92b4ff";
          input = "f7f4ffff";
          match = "ffe2a3ff";
          selection = "3a294dff";
          selection-text = "ffffffff";
          selection-match = "ffd7eeff";
          counter = "bfcfffff";
          border = "ffd6ec33";
        };
      };
    };

    home.packages = [pkgs.inter];
  };
}
