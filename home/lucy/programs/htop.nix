{ config, pkgs, lib, ... }:

{
  options.lucy.htop = {
    enable = lib.mkEnableOption "lucy's htop configuration";
  };

  config = lib.mkIf config.lucy.htop.enable {
    programs.htop = {
      enable = true;
      settings = {
        update_processes = true;
        detailed_cpu_time = false;
        cpu_avg = true;
        delay = 15;
      };
    };

    home.activation.removeHtopConflict = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rm -rf "$HOME/.config/htop"
    '';
  };
}
