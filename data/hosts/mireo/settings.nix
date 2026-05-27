{
  lib,
  pkgs,
  ...
}: let
  netbootxyzArm64 = pkgs.fetchurl {
    url = "https://github.com/netbootxyz/netboot.xyz/releases/download/2.0.88/netboot.xyz-arm64.efi";
    sha256 = "sha256-AeW92FU65XVJKGPi+A/iz7Jvtb7wKIO3xG3Cx7v4kRg=";
  };
in {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@mireo";

  networking.hostName = "mireo";
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp4s0";
    address = ["192.168.178.25/24"];
    routes = [
      {
        Gateway = "192.168.178.1";
      }
    ];
    networkConfig = {
      DNS = ["1.1.1.1" "9.9.9.9"];
      IPv6AcceptRA = false;
    };
  };
  systemd.network.networks."20-lan-enp9s0" = {
    matchConfig.Name = "enp9s0";
    networkConfig.Bridge = "br0";
  };
  systemd.network.networks."21-lan-enp3s0f0" = {
    matchConfig.Name = "enp3s0f0";
    networkConfig.Bridge = "br0";
  };
  systemd.network.networks."22-lan-enp3s0f1" = {
    matchConfig.Name = "enp3s0f1";
    networkConfig.Bridge = "br0";
  };
  systemd.network.netdevs."30-br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
  };
  systemd.network.networks."30-br0" = {
    matchConfig.Name = "br0";
    address = ["10.8.0.1/24"];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
    };
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp4s0";
    internalInterfaces = ["br0"];
  };

  networking.firewall.trustedInterfaces = ["br0"];
  networking.firewall.interfaces.br0.allowedTCPPorts = [19999 9090];

  # --- dnsmasq: DHCP + DNS + TFTP for LAN (br0) ---
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "br0";
      bind-interfaces = true;
      domain-needed = true;
      bogus-priv = true;
      dhcp-authoritative = true;
      dhcp-range = ["10.8.0.100,10.8.0.199,255.255.255.0,24h"];
      dhcp-option = [
        "option:router,10.8.0.1"
        "option:dns-server,10.8.0.1"
      ];
      dhcp-host = [
        "84:2a:fd:4e:bd:7e,omen,10.8.0.176"
        "50:7b:9d:e8:86:9a,p50,10.8.0.122"
        "00:1d:72:9e:25:83,x61,10.8.0.163"
        "d0:50:99:95:7b:13,client-124,10.8.0.124"
      ];
      enable-tftp = true;
      tftp-root = "/etc/netboot";
      dhcp-userclass = "set:ipxe,iPXE";
      dhcp-match = [
        "set:efiarm64,option:client-arch,11"
        "set:efi64,option:client-arch,7"
        "set:efi64,option:client-arch,9"
      ];
      dhcp-boot = [
        "tag:ipxe,menu.ipxe"
        "tag:efiarm64,netboot.xyz-arm64.efi"
        "tag:efi64,ipxe.efi"
        "tag:!efi64,undionly.kpxe"
      ];
      server = ["1.1.1.1" "9.9.9.9"];
    };
  };

  # TFTP netboot files
  environment.etc = {
    "netboot/undionly.kpxe".source = "${pkgs.ipxe}/undionly.kpxe";
    "netboot/ipxe.efi".source = "${pkgs.ipxe}/ipxe.efi";
    "netboot/netboot.xyz.efi".source = "${pkgs.netbootxyz-efi}";
    "netboot/netboot.xyz-arm64.efi".source = netbootxyzArm64;
    "netboot/menu.ipxe".text = ''
      #!ipxe
      menu mireo netboot
      item netbootxyz  netboot.xyz
      item shell       iPXE shell
      item reboot      Reboot
      item exit        Exit back to firmware
      choose --default netbootxyz --timeout 5000 target && goto ''${target}

      :netbootxyz
      chain https://boot.netboot.xyz/menu.ipxe

      :shell
      shell

      :reboot
      reboot

      :exit
      exit
    '';
  };

  # --- NFS export /data ---
  services.nfs.server = {
    enable = true;
    exports = ''
      /data 10.8.0.0/24(rw,sync,no_subtree_check,no_root_squash)
    '';
  };

  # --- netdata monitoring ---
  services.netdata = {
    enable = true;
    config = {
      global = {
        "update every" = 1;
      };
      web = {
        "bind to" = "10.8.0.1";
        "default port" = 19999;
        "allow connections from" = "localhost 10.8.*";
        "allow dashboard from" = "localhost 10.8.*";
      };
    };
  };

  # --- Tailscale network unit (mark as unmanaged) ---
  systemd.network.networks."50-tailscale" = {
    matchConfig.Name = "tailscale0";
    linkConfig = {
      ActivationPolicy = "manual";
      Unmanaged = true;
    };
  };

  boot.loader.systemd-boot.enable = true;

  nix.settings.substituters = lib.mkBefore ["http://omen:5000"];
}
