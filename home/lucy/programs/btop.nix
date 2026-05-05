{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.btop.enable {
    programs.btop.settings = {
      proc_gradient = false;
      proc_tree = true;
      rounded_corners = true;
      show_gpu_info = "Auto";
      truecolor = true;
      update_ms = 1200;
      vim_keys = true;
    };
  };
}
