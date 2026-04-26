{ config, lib, ... }:

{
  options.lucy.fzf = {
    enable = lib.mkEnableOption "fzf configuration";
  };

  config = lib.mkIf config.lucy.fzf.enable {
    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      defaultCommand = "fd --type f --hidden --strip-cwd-prefix --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --strip-cwd-prefix --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --strip-cwd-prefix --exclude .git";
      defaultOptions = [
        "--height=45%"
        "--layout=reverse"
        "--border=rounded"
        "--preview-window=right,60%,border-left"
        "--bind=ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down"
      ];
    };
  };
}
