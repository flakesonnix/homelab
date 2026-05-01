{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.git.enable {
    programs.git = {
      settings = {
        user = {
          name = "Lucy";
          email = "lucy@example.com";
        };
        alias = {
          co = "checkout";
          st = "status";
          ci = "commit";
          br = "branch";
          lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        };
      };
    };
  };
}
