{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors;
in {
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
        highlight_threads = true;
        find_intervals = true;
        find_intervals_saved = 1;
        highlight_changes = true;
        highlight_changes_delay = 5;
        header_margin = true;
        expand_processe_tree = false;
        hide_kernel_threads = true;
        hide_userland_threads = true;
        ignore_older_processes = true;
        show_program_path = true;
        show_merged_command = false;
        show_decorations = true;
        show_process_command = true;
        show_cpu_frequency = true;
        show_cpu_temperature = true;
        show_cpu_usage = true;
        show_memory = true;
        show_swap = true;
        show_tasks = true;
        show_load = true;
        show_system = true;
        show_processe = true;
        show_time = true;
        show_uptime = true;
      };
    };

    };
}
