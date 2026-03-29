{ config, lib, pkgs, ... }:

{
  options.lucy.ssh = {
    enable = lib.mkEnableOption "SSH configuration";
  };

  config = lib.mkIf config.lucy.ssh {
    programs.ssh = {
      enable = true;
      controlMaster = "auto";
      controlPath = "~/.ssh/sockets/%r@%h-%p";
      controlPersist = "10m";
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
      hashKnownHosts = true;
      addKeysToAgent = "yes";

      matchBlocks = {
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

        "localhost" = {
          hostname = "localhost";
          StrictHostKeyChecking = "accept-new";
          UserKnownHostsFile = "~/.ssh/known_hosts_local";
        };
      };

      knownHosts = [
        {
          hostNames = [ "github.com" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        }
        {
          hostNames = [ "gitlab.com" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF7w4xFUxO6lnI9Kx3E1V8Yq4J4RQG2LVmV9rFk4F3s0";
        }
        {
          hostNames = [ "sr.ht" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAAOKu4T3jGAMfXL6Q6J3iY7VqX8Y2K3E5V9N4B8M6L2P1K";
        }
      ];
    };

    home.file.".ssh/config".text = ''
      # SSH configuration managed by home-manager
      # Do not edit manually
    '';
  };
}
