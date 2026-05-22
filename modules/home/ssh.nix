{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      enableDefaultConfig = false;

      settings = {
        "*" = {
          ForwardAgent = false;
          AddKeysToAgent = "no";
          Compression = false;
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "auto";
          ControlPath = "~/.ssh/sockets/%r@%h-%p";
          ControlPersist = "10m";
        };
        "github.com" = {
          HostName = "github.com";
          IdentityFile = "~/.ssh/lucy_git";
          HashKnownHosts = true;
          AddKeysToAgent = "yes";
        };
        "gitlab.com" = {
          HostName = "gitlab.com";
          IdentityFile = "~/.ssh/lucy_git";
        };
        "sr.ht" = {
          HostName = "sr.ht";
          IdentityFile = "~/.ssh/lucy_git";
        };
      };
    };
  };
}
