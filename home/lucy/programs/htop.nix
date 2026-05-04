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

    xdg.configFile."htop/htrc".text = ''
      config_reader_min_escape_timeout = 1000
      hide_kernel_threads = 1
      hide_userland_threads = 1
      highlight_base_name = 1
      highlight_megabytes = 1
      highlight_threads = 1
      find_intervals = 1
      find_intervals_saved = 1
      header_margin = 1
      expand_processe_tree = 0
      tree_view = 1
      show_program_path = 1
      show_decorations = 1
      show_process_command = 1
      show_cpu_frequency = 1
      show_cpu_temperature = 1
      update_processes = 1
      account_guest_in_cpu_meter = 0
      cpu_count_from_one = 0
      show_cpu_usage = 1
      show_memory = 1
      show_swap = 1
      show_tasks = 1
      show_load = 1
      show_system = 1
      show_processe = 1
      show_time = 1
      show_uptime = 1
      detailed_cpu_time = 0
      cpu_avg = 1
      delay = 15
      color_scheme = 1
    '';
  };
}
