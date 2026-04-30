{
  config,
  lib,
  ...
}: {
  options.lucy.ssh = {
    enable = lib.mkEnableOption "SSH configuration";
    extraHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          host = lib.mkOption {type = lib.types.str;};
          user = lib.mkOption {type = lib.types.str;};
          identityFile = lib.mkOption {type = lib.types.str;};
        };
      });
      default = {};
      description = "Additional SSH hosts to configure";
    };
  };

  config = lib.mkIf config.lucy.ssh.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks =
        {
          "*" = {
            controlMaster = "auto";
            controlPath = "~/.ssh/sockets/%r@%h-%p";
            controlPersist = "10m";
            serverAliveInterval = 60;
            serverAliveCountMax = 3;
          };

          "github.com" = {
            hostname = "github.com";
            identityFile = "~/.ssh/lucy_git";
            hashKnownHosts = true;
            addKeysToAgent = "yes";
          };

          "gitlab.com" = {
            hostname = "gitlab.com";
            identityFile = "~/.ssh/lucy_git";
          };

          "sr.ht" = {
            hostname = "sr.ht";
            identityFile = "~/.ssh/lucy_git";
          };
        }
        // lib.mapAttrs (_n: v: {
          inherit (v) host;
          inherit (v) user;
          inherit (v) identityFile;
        })
        config.lucy.ssh.extraHosts;
    };
  };
}
