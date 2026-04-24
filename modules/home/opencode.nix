{ lib, config, pkgs, ... }:

{
  options.lucy.opencode = {
    enable = lib.mkEnableOption "Opencode AI coding agent";
  };

  config = lib.mkIf config.lucy.opencode.enable {
    home.packages = [
      pkgs.opencode
    ];

    programs.bash.initExtra = ''
      export PATH="${builtins.getEnv "HOME"}/.opencode/bin:$PATH"
      export PATH="$(npm prefix -g)/bin:$PATH"
    '';
    programs.zsh.initContent = ''
      export PATH="${builtins.getEnv "HOME"}/.opencode/bin:$PATH"
      export PATH="$(npm prefix -g)/bin:$PATH"
    '';
  };
}
