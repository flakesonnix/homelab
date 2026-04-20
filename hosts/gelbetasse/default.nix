{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "gelbetasse";
  networking.domain = "internal.gelbetasse.org";
  networking.nameservers = [ "127.0.0.1" ];

  networking.firewall.enable = false;

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    settings = {
      server_url = "https://headscale.internal.gelbetasse.org";
      dns = {
        base_domain = "internal.gelbetasse.org";
        magic_dns = true;
        nameservers.global = [ "8.8.8.8" "8.8.4.4" ];
      };
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
    settings = {
      server = [ "8.8.8.8" "8.8.4.4" ];
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

  system.stateVersion = "25.05";
}