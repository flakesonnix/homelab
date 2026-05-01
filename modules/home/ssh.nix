{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      enableDefaultConfig = false;

      matchBlocks = {
        "*" = {
          controlMaster = lib.mkDefault "auto";
          controlPath = lib.mkDefault "~/.ssh/sockets/%r@%h-%p";
          controlPersist = lib.mkDefault "10m";
          serverAliveInterval = lib.mkDefault 60;
          serverAliveCountMax = lib.mkDefault 3;
        };

        "github.com" = {
          hostname = lib.mkDefault "github.com";
          identityFile = lib.mkDefault "~/.ssh/lucy_git";
          hashKnownHosts = lib.mkDefault true;
          addKeysToAgent = lib.mkDefault "yes";
        };

        "gitlab.com" = {
          hostname = lib.mkDefault "gitlab.com";
          identityFile = lib.mkDefault "~/.ssh/lucy_git";
        };

        "sr.ht" = {
          hostname = lib.mkDefault "sr.ht";
          identityFile = lib.mkDefault "~/.ssh/lucy_git";
        };
      };
    };
  };
}
