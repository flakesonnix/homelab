{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./packages.nix
    ./programs/easyeffects
    ../../modules/home/stylix.nix
  ];

  lucy.shell.enable = true;
  lucy.git.enable = true;
  lucy.editor.enable = true;
  lucy.easyeffects.enable = true;

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "niri/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "battery" "cpu" "memory" ];
        "niri/workspaces" = {
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
        font-family: monospace;
        font-size: 12px;
      }
      window#waybar {
        background: #1a1520;
        color: #a990af;
      }
    '';
  };

  home.packages = with pkgs; [
    jetbrains-mono
  ];

  stylix = {
    enable = true;
    base16Scheme = {
      scheme = "Custom";
      base00 = "1a1520";
      base01 = "2e2334";
      base02 = "52374f";
      base03 = "6c70a8";
      base04 = "7986a3";
      base05 = "a990af";
      base06 = "d8b3cf";
      base07 = "f8f2f7";
      base08 = "de99ac";
      base09 = "bf8c79";
      base0A = "778ad8";
      base0B = "a1a5e0";
      base0C = "b8d4e8";
      base0D = "96656a";
      base0E = "d8b3cf";
      base0F = "52374f";
    };
    targets.gnome.enable = false;
    targets.waybar.enable = true;
    targets.waybar.font = "monospace";
  };

  gtk = {
    gtk4.theme = null;
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
