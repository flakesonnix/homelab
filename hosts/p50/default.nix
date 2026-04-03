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
    ../../modules/nixos/network.nix
    ../../modules/nixos/ssh-keys.nix
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

  environment.systemPackages = with pkgs; [
    hyfetch-wrapped
    gnomeExtensions.dash-to-dock
  ];

  users.users.lucy.packages = with pkgs; [
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
  ];

  programs.noisetorch.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = true;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 24800 ];
  };

  ssh-keys = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
    comment = "lucy@p50";
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age = {
      generateKey = true;
    };
    secrets = { };
  };

  system.stateVersion = "25.11";
}
