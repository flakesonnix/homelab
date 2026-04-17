{ config, lib, pkgs, ... }:

{
  options.lucy.ssh = {
    enable = lib.mkEnableOption "SSH configuration";
    extraHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          host = lib.mkOption { type = lib.types.str; };
          user = lib.mkOption { type = lib.types.str; };
          identityFile = lib.mkOption { type = lib.types.str; };
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

      matchBlocks = {
        "*" = {
          controlMaster = "auto";
          controlPath = "~/.ssh/sockets/%r@%h-%p";
          controlPersist = "10m";
          serverAliveInterval = 60;
          serverAliveCountMax = 3;
          hashKnownHosts = true;
          addKeysToAgent = "yes";
        };

        "github.com" = {
          identityFile = "~/.ssh/lucy_git";
          hostname = "github.com";
        };

        "gitlab.com" = {
          identityFile = "~/.ssh/lucy_git";
          hostname = "gitlab.com";
        };

        "sr.ht" = {
          identityFile = "~/.ssh/lucy_git";
          hostname = "sr.ht";
        };
      } // lib.mapAttrs (n: v: { host = v.host; user = v.user; identityFile = v.identityFile; }) config.lucy.ssh.extraHosts;
    };

    home.file.".ssh/config".text = ''
      # SSH configuration managed by home-manager
      # Do not edit manually
    '';
  };
}
