{ config, pkgs, lib, ... }:

{
  options.lucy.btop = {
    enable = lib.mkEnableOption "lucy's btop configuration";
  };

  config = lib.mkIf config.lucy.btop.enable {
    programs.btop = {
      enable = true;
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
  };
}
