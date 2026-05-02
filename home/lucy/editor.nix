{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.neovim.enable {
    programs.neovim = {
      defaultEditor = true;
      withRuby = true;
      withPython3 = true;
    };
  };
}
