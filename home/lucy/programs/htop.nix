{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.htop.enable {
    programs.htop = {
      settings = {
        update_processes = true;
        detailed_cpu_time = false;
        cpu_avg = true;
        delay = 15;
        tree_view = true;
        highlight_base_name = true;
        highlight_megabytes = true;
        shadow_other_users = false;
      };
    };
  };
}
