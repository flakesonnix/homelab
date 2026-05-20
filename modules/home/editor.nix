{
  lib,
  config,
  pkgs,
  ...
}: let
  vimOpts = {
    number = true;
    relativenumber = true;
    tabstop = 2;
    shiftwidth = 2;
    expandtab = true;
    smartindent = true;
    wrap = true;
    linebreak = true;
    termguicolors = true;
  };

  luaConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      k: v: "vim.opt.${k} = ${builtins.toJSON v}"
    )
    vimOpts);
in {
  options.lucy.editor.enable = lib.mkEnableOption "Neovim editor config";

  config = lib.mkIf config.lucy.editor.enable {
    programs.neovim = {
      enable = true;
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
      ];
      initLua = luaConfig;
    };
  };
}
