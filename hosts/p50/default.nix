{ config, pkgs, wrappers, ... }:

let
  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "trans";
    };
  };

  niri-wrapped = wrappers.wrapperModules.niri.apply {
    inherit pkgs;
    settings = {
      input = {
        keyboard = {
          xkb = {
            layout = "us";
          };
        };
        touchpad = {
          tap = null;
          "natural-scroll" = null;
        };
      };
      binds = {
        "Mod+Shift+Slash" = { "show-hotkey-overlay" = null; };
        "Mod+Return" = { spawn = "alacritty"; };
        "Mod+D" = { spawn = "fuzzel"; };
        "Mod+Q" = { "close-window" = null; };
        "Mod+W" = { "close-window" = null; };
        "Mod+Left" = { "focus-column-left" = null; };
        "Mod+Down" = { "focus-window-down" = null; };
        "Mod+Up" = { "focus-window-up" = null; };
        "Mod+Right" = { "focus-column-right" = null; };
        "Mod+H" = { "focus-column-left" = null; };
        "Mod+J" = { "focus-window-down" = null; };
        "Mod+K" = { "focus-window-up" = null; };
        "Mod+L" = { "focus-column-right" = null; };
        "Mod+Ctrl+Left" = { "move-column-left" = null; };
        "Mod+Ctrl+Down" = { "move-window-down" = null; };
        "Mod+Ctrl+Up" = { "move-window-up" = null; };
        "Mod+Ctrl+Right" = { "move-column-right" = null; };
        "Mod+Ctrl+H" = { "move-column-left" = null; };
        "Mod+Ctrl+J" = { "move-window-down" = null; };
        "Mod+Ctrl+K" = { "move-window-up" = null; };
        "Mod+Ctrl+L" = { "move-column-right" = null; };
        "Mod+Page_Down" = { "focus-workspace-down" = null; };
        "Mod+Page_Up" = { "focus-workspace-up" = null; };
        "Mod+U" = { "focus-workspace-down" = null; };
        "Mod+I" = { "focus-workspace-up" = null; };
        "Mod+1" = { "focus-workspace" = 1; };
        "Mod+2" = { "focus-workspace" = 2; };
        "Mod+3" = { "focus-workspace" = 3; };
        "Mod+4" = { "focus-workspace" = 4; };
        "Mod+5" = { "focus-workspace" = 5; };
        "Mod+6" = { "focus-workspace" = 6; };
        "Mod+7" = { "focus-workspace" = 7; };
        "Mod+8" = { "focus-workspace" = 8; };
        "Mod+9" = { "focus-workspace" = 9; };
        "Mod+Comma" = { "consume-window-into-column" = null; };
        "Mod+Period" = { "expel-window-from-column" = null; };
        "Mod+R" = { "switch-preset-column-width" = null; };
        "Mod+F" = { "maximize-column" = null; };
        "Mod+Shift+F" = { "fullscreen-window" = null; };
        "Mod+C" = { "center-column" = null; };
        "Print" = { screenshot = null; };
        "Mod+Shift+E" = { quit = null; };
      };
      spawn-at-startup = [
        "waybar"
        "wpaperd"
      ];
      layout = {
        gaps = 16;
      };
      extraConfig = ''
        prefer-no-csd
      '';
    };
  };
in

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "p50";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";

  i18n.inputMethod.enable = false;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  programs.niri.enable = true;

  environment.systemPackages = [
    niri-wrapped.wrapper
    hyfetch-wrapped
  ];

  services.displayManager.sessionPackages = [ niri-wrapped.wrapper ];

  users.users.lucy.packages = with pkgs; [
    alacritty
    zathura
    fzf
    bat
    btop
    htop
    vesktop
    vlc
    p7zip
    thunderbird
  ];

  programs.noisetorch.enable = true;

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
