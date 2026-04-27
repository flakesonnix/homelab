{ config, lib, ... }:

{
  options.lucy.editor = {
    enable = lib.mkEnableOption "lucy's editor configuration";
  };

  config = lib.mkIf config.lucy.editor.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      withRuby = true;
      withPython3 = true;
    };
  };
}
