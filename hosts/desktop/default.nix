{ lib, config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/gnome-extensions.nix
    ../../modules/nixos/hyprland.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/openclaude.nix
    ../../modules/nixos/dect.nix
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
  lucy.gnome.enable = false;
  lucy.hyprland.enable = true;
  lucy.gnomeExtensions.enable = false;

  hardware.nvidia.powerManagement.enable = lib.mkForce false;
  lucy.openclaude.enable = false;

  lucy.dect.enable = true;

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

  networking.firewall.allowedTCPPorts = [ 21 445 139 3001 7236 ];
  networking.firewall.allowedUDPPorts = [ 137 138 7236 ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 10000; to = 20000; }  # RTP audio
  ];

  router = {
    enable = true;
    interfaces.lan = {
      ipv4 = {
        enableForwarding = true;
        addresses = [
          {
            address = "10.0.0.1";
            prefixLength = 8;
          }
        ];
        kea = {
          enable = true;
          settings = {
            valid-lifetime = 7200;
            subnet4 = [
              {
                subnet = "10.0.0.0/8";
                pools = [
                  {
                    pool = "10.0.0.128/25";
                  }
                ];
                option-data = [
                  {
                    name = "routers";
                    data = "10.0.0.1";
                  }
                  {
                    name = "domain-name-servers";
                    data = "10.0.0.1";
                  }
                  {
                    name = "domain-name";
                    data = "internal.meow";
                  }
                ];
              }
            ];
          };
        };
      };
    };
  };

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
