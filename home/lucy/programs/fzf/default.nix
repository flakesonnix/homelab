{
  lib,
  ...
}: {
  config.programs.fzf = {
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
    ];
  };
}
