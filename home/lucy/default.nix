{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/packages.nix
    ./programs/easyeffects
    ./programs/htop.nix
    ./programs/btop.nix
    ./programs/gnome-theme.nix
    ./programs/openclaude.nix
    ../../modules/home/stylix.nix
    ../../modules/home/ssh.nix
  ];

  lucy.shell.enable = true;
  lucy.git.enable = true;
  lucy.editor.enable = true;
  lucy.easyeffects.enable = true;
  lucy.htop.enable = true;
  lucy.btop.enable = true;
  lucy.stylix.enable = true;
  lucy.gnomeTheme.enable = true;
  lucy.ssh.enable = true;
  lucy.ssh.extraHosts = {
    "p50" = {
      host = "192.168.178.31";
      user = "lucy";
      identityFile = "~/.ssh/id_ed25519";
    };
  };
  lucy.programs.jetbrains-mono = true;
  lucy.programs.wpaperd = true;
  lucy.programs.comma = true;
  lucy.programs.android-studio = true;
  lucy.openclaude.enable = true;

  programs.neovim = {
    withRuby = true;
    withPython3 = true;
  };

  services.flatpak = {
    enable = true;
    packages = [
      "com.teamspeak.TeamSpeak"
    ];
  };

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "wlr/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "battery" "cpu" "memory" ];
        "wlr/workspaces" = {
          format = "{}";
        };
        clock = {
          format = "{:%H:%M}";
          interval = 1;
        };
        cpu = {
          format = "{}%";
          interval = 2;
        };
        memory = {
          format = "{}%";
          interval = 2;
        };
        battery = {
          format = "{}%";
          interval = 60;
        };
      }
    ];
    style = ''
      * {
        font-family: "JetBrains Mono", monospace;
        font-size: 12px;
      }
      window#waybar {
        background: rgba(42, 31, 45, 0.9);
        color: #ffb6c1;
        border-radius: 8px;
      }
      button {
        color: #ff69b4;
        background: transparent;
        border: none;
      }
      button:hover {
        color: #ff1493;
        background: rgba(255, 105, 180, 0.2);
      }
    '';
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
