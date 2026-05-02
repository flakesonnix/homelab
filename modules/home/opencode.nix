{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.programs.opencode.enable {
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
