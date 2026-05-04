{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.fzf.enable {
    programs.fzf = {
      enable = true;
      defaultOptions = [
        "--height 40%"
        "--border"
        "--preview 'bat --color=always {}'"
        "--preview-window right:60%:wrap"
        "--bind ctrl-/:toggle-preview"
        "--bind ctrl-u:half-page-up"
        "--bind ctrl-d:half-page-down"
        "--bind alt-j:preview-down"
        "--bind alt-k:preview-up"
        "--color hl:#ad8aec"
        "--color hl+:#ffd6ec"
        "--color pointer:#cba6f7"
        "--color marker:#f38ba8"
        "--color bg+:#313244"
        "--color bg:#1e1e2e"
        "--color fg:#cdd6f4"
        "--color border:#45475a"
      ];
      colors = {
        "hl" = "#ad8aec";
        "hl+" = "#ffd6ec";
        "pointer" = "#cba6f7";
        "marker" = "#f38ba8";
        "bg+" = "#313244";
        "bg" = "#1e1e2e";
        "fg" = "#cdd6f4";
        "border" = "#45475a";
      };
    };
  };
}
