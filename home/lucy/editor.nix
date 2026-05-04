{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: {
  config = lib.mkIf config.programs.neovim.enable {
    programs.neovim = {
      defaultEditor = true;
      withRuby = true;
      withPython3 = true;
      extraPackages = with pkgs; [tree-sitter];
      plugins = with pkgs.vimPlugins; [
        nvim-lspconfig
        nvim-treesitter
        telescope-nvim
        plenary-nvim
        nvim-web-devicons
        gruvbox-nvim
      ];
      extraConfig = ''
        set number
        set relativenumber
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set smartindent
        set wrap
        set linebreak
        set termguicolors
        colorscheme gruvbox
      '';
    };
  };
}
