{
  lib,
  config,
  ...
}: let
  pathExports = ''
    export PATH="${config.home.homeDirectory}/.opencode/bin:$PATH"
    export PATH="$(npm prefix -g)/bin:$PATH"
  '';
in {
  config = lib.mkIf config.programs.opencode.enable {
    programs.bash.initExtra = pathExports;
    programs.zsh.initContent = pathExports;
  };
}
