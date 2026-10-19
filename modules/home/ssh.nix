{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.ssh.enable {
    # OpenSSH rejects config symlinked into /nix/store (owned by
    # nobody:nogroup, 444). Replace the HM symlink with a regular
    # 600 file after linking so `ssh` doesn't fail with
    # "Bad owner or permissions".
    home.file.".ssh/config".force = true;
    home.activation.fixSshConfigPermissions = lib.hm.dag.entryAfter ["linkGeneration"] ''
      cfg="$HOME/.ssh/config"
      if [ -L "$cfg" ]; then
        run cp -L "$cfg" "$cfg.tmp"
        run rm "$cfg"
        run mv "$cfg.tmp" "$cfg"
        run chmod 600 "$cfg"
      elif [ -e "$cfg" ]; then
        run chmod 600 "$cfg"
      fi
      if [ -d "$HOME/.ssh" ]; then
        run chmod 700 "$HOME/.ssh"
      fi
    '';

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
