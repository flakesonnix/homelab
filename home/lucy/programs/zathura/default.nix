{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
in {
  config = lib.mkIf config.programs.zathura.enable {
    programs.zathura = {
      extraConfig = ''
        set default-zoom fit-width
        set adjust-open best-fit
        set font "JetBrainsMono Nerd Font 12"
        set recolor false
        set scroll-page-aware true
        set selection-clipboard clipboard
        set window-title-basename true
        set synctex true
        set page-padding 12
        set scroll-wrap true
        set advance-presentation-wrap true
        set zoom-center true
        set highlight-color "${colors.base0D}66"
        set highlight-active-color "${colors.base0A}66"
        set search-hilight-color "${colors.base0A}66"
        set search-hilight-active-color "${colors.base0D}66"
        set link-color "${colors.base0C}"
        set link-active-color "${colors.base0B}"
        set form-field-background "${colors.base01}"
        set form-field-border-color "${colors.base02}"
        set statusbar-fg "${colors.base05}"
        set statusbar-bg "${colors.base00}"
        set inputbar-fg "${colors.base05}"
        set inputbar-bg "${colors.base01}"
        set notification-fg "${colors.base05}"
        set notification-bg "${colors.base00}"
        set notification-error-fg "${colors.base08}"
        set notification-error-bg "${colors.base00}"
        set index-fg "${colors.base05}"
        set index-bg "${colors.base00}"
        set index-active-fg "${colors.base00}"
        set index-active-bg "${colors.base0D}"
        set completion-fg "${colors.base05}"
        set completion-bg "${colors.base01}"
        set completion-highlight-fg "${colors.base00}"
        set completion-highlight-bg "${colors.base0D}"
      '';
      mappings = {
        D = "toggle_page_mode";
        i = "recolor";
        r = "reload";
      };
    };
  };
}
