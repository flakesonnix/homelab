{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors;
in {
  config = lib.mkIf config.programs.btop.enable {
    programs.btop = {
      settings = {
        proc_gradient = false;
        proc_tree = true;
        rounded_corners = true;
        show_gpu_info = "Auto";
        truecolor = true;
        update_ms = 1200;
        vim_keys = true;
      };
    };

    xdg.configFile."btop/btop.conf".text = ''
      [main]
      graph_symbol = "█"
      theme_background = false
      theme = "monokai"
      color_theme = 1
      rounded_corners = true
      update_ms = 1200
      proc_gradient = false
      proc_tree = true
      vim_keys = true
      truecolor = true
      show_gpu_info = Auto

      [graphs]
      symbol = "█"
      symbol_filled = "█"
      symbol_empty = "░"
    '';
  };
}
