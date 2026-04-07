{ lib, config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/gnome-extensions.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/openclaude.nix
    ../../modules/desktop/audio-zeroconf.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-6665f9fc-a50c-4ec2-b301-ab49ffe83b86".device = "/dev/disk/by-uuid/6665f9fc-a50c-4ec2-b301-ab49ffe83b86";

  networking.hostName = "desktop";
  networking.staticIP = {
    enable = true;
    address = "192.168.178.2";
    prefixLength = 24;
    gateway = "192.168.178.1";
    interface = "enp8s0";
  };

  boot.initrd.network.ssh.port = 2223;
  boot.initrd.availableKernelModules = [ "r8169" ];

  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  lucy.nvidia.enable = true;
  lucy.gnome.enable = true;
  lucy.gnome.wayland = false;
  lucy.gnomeExtensions.enable = true;

  hardware.nvidia.powerManagement.enable = lib.mkForce false;
  lucy.openclaude.enable = false;

  hq.audio.backend = "pipewire";
  hq.audio.sink = true;
  hq.audio.sinkName = "Pulsebert";
  # hq.audio.airplay = true;
  # hq.audio.airplayName = "Glotzbert";

  lucy.basePackages = with pkgs; [
    deskflow
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
    shares = {
      public = {
        path = "/srv/public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "public" = "yes";
        "force user" = "lucy";
        "force group" = "users";
      };
    };
  };

  services.vsftpd = {
    enable = true;
    localUsers = true;
    writeEnable = true;
    anonymousUser = false;
  };

  services.uptime-kuma.enable = true;

  networking.firewall.allowedTCPPorts = [ 21 445 139 3001 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];

  systemd.tmpfiles.rules = [
    "d /srv/public 0755 lucy users -"
  ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  system.stateVersion = "25.11";
}
