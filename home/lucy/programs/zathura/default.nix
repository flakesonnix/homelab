{ config, lib, ... }:

{
  options.lucy.zathura = {
    enable = lib.mkEnableOption "zathura configuration";
  };

  config = lib.mkIf config.lucy.zathura.enable {
    programs.zathura = {
      enable = true;
      options = {
        adjust-open = "best-fit";
        font = "JetBrainsMono Nerd Font 12";
        guioptions = "none";
        page-padding = 12;
        recolor = false;
        scroll-page-aware = true;
        selection-clipboard = "clipboard";
        show-hidden = true;
        synctex = true;
        window-title-basename = true;
      };
      mappings = {
        D = "toggle_page_mode";
        i = "recolor";
        r = "reload";
      };
      extraConfig = ''
        set default-zoom fit-width
        set forward-search-command "nvim --remote-silent +%{line} %{input}"
      '';
    };
  };
}
