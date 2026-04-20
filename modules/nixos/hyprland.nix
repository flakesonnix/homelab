{ lib, config, pkgs, inputs, ... }:

{
  options.lucy.hyprland = {
    enable = lib.mkEnableOption "Hyprland compositor configuration";
  };

  config = lib.mkIf config.lucy.hyprland.enable {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
    };

    environment.etc."hypr/hyprland.conf".source = "/home/lucy/Documents/dotfiles/modules/nixos/hyprland.conf";
    environment.etc."hypr/hyprland.conf".forceTrulyLink = true;

    environment.systemPackages = with pkgs; [
      hyprlock
      hypridle
      waybar
      wlogout
      wl-clipboard
      grim
      slurp
      brightnessctl
      playerctl
      networkmanagerapplet
      blueman
      wofi
    ];

    home-manager.users.lucy = {
      programs.wofi = {
        enable = true;
        settings = {
          width = 600;
          height = 400;
          show = "drun";
          allow_images = false;
        };
        style = ''
          window {
            background-color: #1a1423;
            border-radius: 8px;
          }
          #input {
            background-color: #2a2436;
            color: #c6a7ff;
            border: none;
            border-radius: 4px;
            padding: 8px;
            margin: 4px;
          }
          #entry:selected {
            background-color: #c678dd;
            color: #1a1423;
          }
          #text {
            color: #abb2bf;
          }
          #text:selected {
            color: #1a1423;
          }
        '';
      };
    };

    security.polkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}