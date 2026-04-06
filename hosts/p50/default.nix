{ config, pkgs, wrappers, ... }:

let
  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/gnome-extensions.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/latex.nix
    ../../modules/nixos/openclaude.nix
    ../../modules/nixos/asterisk.nix
    ../../modules/nixos/audio-stream.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "p50";

  networking.staticIP = {
    enable = true;
    address = "192.168.178.31";
    prefixLength = 24;
    gateway = "192.168.178.1";
    interface = "enp0s31f6";
  };

  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  lucy.gnome.enable = true;
  lucy.gnome.wayland = true;
  lucy.gnomeExtensions.enable = true;
  lucy.latex.enable = true;
  lucy.openclaude.enable = false;

  hq.audio.streamTo = "192.168.178.2";

  services.asteriskLocal = {
    enable = false;  # Disabled by default, enable to use
    openFirewall = true;
    phones = {
      desk1 = { extension = "1001"; password = "secret123"; };
      desk2 = { extension = "1002"; password = "secret456"; };
    };
    extraExtensions = ''
      ; Ring all desks at once
      exten => 9000,1,Dial(PJSIP/desk1&PJSIP/desk2,20)
      same => n,Hangup()
    '';
  };

  lucy.basePackages = with pkgs; [
    alacritty
    zathura
    fzf
    bat
    vesktop
    vlc
    p7zip
    thunderbird
    deskflow
    keepassxc
    nodejs_22
    ausweisapp
  ];

  lucy.hostPackages = with pkgs; [ ];

  environment.systemPackages = with pkgs; [
    hyfetch-wrapped
  ];

  programs.noisetorch.enable = true;

  services.openssh.settings.PermitRootLogin = "prohibit-password";

  system.stateVersion = "25.11";
}
