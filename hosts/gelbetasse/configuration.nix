{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  lucy.base.isServer = true;

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "gelbetasse";
  networking.domain = "gelbetasse.org";
  networking.nameservers = [ "127.0.0.1" ];

  networking.firewall.enable = false;

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    serverUrl = "https://headscale.internal.gelbetasse.org";
    dns = {
      baseDomain = "internal.gelbetasse.org";
      magicDns = true;
    };
    settings = {
      logtail.enabled = false;
      ephemeral-node-inactivity-timeout = "30m";
      node-update.check-interval = "10s";
    };
  };

  services.nginx.virtualHosts."headscale.internal.gelbetasse.org" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.headscale.port}";
      proxyWebsockets = true;
    };
  };

  services.dnsmasq = {
    enable = true;
    servers = [ "8.8.8.8" "8.8.4.4" ];
    settings = {
      cache-size = 1000;
      address = [ "/headscale.internal.gelbetasse.org/127.0.0.1" ];
    };
  };

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
  };

  environment.systemPackages = with pkgs; [
    htop
    vim
    tcpdump
    pciutils
    headscale
  ];

  users.users.root = {
    initialPassword = "root";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS lucy@p50"
    ];
  };

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS lucy@p50"
    ];
  };

  system.stateVersion = "25.05";
}