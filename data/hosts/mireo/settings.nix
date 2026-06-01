{lib, pkgs, ...}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@mireo";

  networking.hostName = "mireo";
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;

  systemd.network.enable = true;
  # FritzBox IPv6 (as of 2026-05-29):
  #   WAN addr:  2a02:3102:4c00:3b::1b5/64
  #   delegated: 2a02:3102:4cec:b500::/64  (assigned to br0 LAN)
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
      IPv6AcceptRA = true;
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
    address = ["10.8.0.1/24" "fd00:cafe:1::1/64"];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6AcceptRA = false;
      LinkLocalAddressing = "ipv6";
    };
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp4s0";
    internalInterfaces = ["br0"];
  };

  networking.firewall.trustedInterfaces = ["br0"];
  networking.firewall.interfaces.br0.allowedTCPPorts = [19999 9090];

  # --- dnsmasq: DHCP + DNS for LAN (br0) ---
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "br0";
      bind-interfaces = true;
      domain-needed = true;
      bogus-priv = true;
      dhcp-authoritative = true;
      enable-ra = true;
      dhcp-range = [
        "10.8.0.100,10.8.0.199,255.255.255.0,24h"
        "::,constructor:br0,ra-stateless,64,24h"
      ];
      dhcp-option = [
        "option:router,10.8.0.1"
        "option:dns-server,10.8.0.1"
      ];
      dhcp-host = [
        "84:2a:fd:4e:bd:7e,omen,10.8.0.176"
        "50:7b:9d:e8:86:9a,p50,10.8.0.122"
        "d0:50:99:95:7b:13,client-124,10.8.0.124"
      ];
      host-record = [
        "grafana,10.8.0.2"
        "network-services,10.8.0.3"
        "monerod,10.8.0.4"
        "yammat,10.8.0.5"
        "cups,10.8.0.6"
        "sshkeys,10.8.0.7"
        "aptcache,10.8.0.8"
        "mireo,10.8.0.1"
        "omen,10.8.0.176"
        "p50,10.8.0.122"
      ];
      server = ["1.1.1.1" "9.9.9.9" "2606:4700:4700::1111" "2620:fe::9"];
    };
  };

  # --- iVentoy PXE server (proxyDHCP mode, web UI :26000) ---
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.iventoy = {
    image = "iventoy/iventoy:latest";
    extraOptions = [
      "--network=host"
      "--privileged"
    ];
    volumes = [
      "/data/iventoy/iso:/iventoy/iso"
      "/data/iventoy/data:/iventoy/data"
    ];
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/ee576a43-066a-4e85-901d-2f03d618bea8";
    fsType = "ext4";
    options = ["defaults" "nofail"];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles.nfs = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h data</name>
        <service>
          <type>_nfs._tcp</type>
          <port>2049</port>
          <txt-record>path=/data</txt-record>
        </service>
      </service-group>
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

  # --- Automatic ISO download for iVentoy ---
  systemd.services.iventoy-fetch-isos = {
    description = "Download Linux ISOs for iVentoy PXE";
    after = ["data.mount"];
    requires = ["data.mount"];
    wants = ["podman-iventoy.service"];
    path = [pkgs.curl pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      ISO_DIR="/data/iventoy/iso"
      mkdir -p "$ISO_DIR"

      dl() {
        local url="$1" file="$2"
        if [ -f "$ISO_DIR/$file" ]; then
          echo "Exists: $file"
          return
        fi
        echo "Downloading $file..."
        curl -fLo "$ISO_DIR/$file.tmp" "$url" && mv "$ISO_DIR/$file.tmp" "$ISO_DIR/$file" || { echo "FAILED: $file"; rm -f "$ISO_DIR/$file.tmp"; return 1; }
      }

      dl "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso" "debian-12-netinst.iso"
      dl "https://files.devuan.org/devuan_daedalus/installer-iso/devuan_daedalus_5.0.0_amd64_netinst.iso" "devuan-daedalus-5-netinst.iso"
      dl "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso" "archlinux-x86_64.iso"
      dl "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-desktop-amd64.iso" "ubuntu-24.04-desktop.iso"
    '';
  };

  systemd.timers.iventoy-fetch-isos = {
    description = "Weekly update of iVentoy ISOs";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Ensure dnsmasq starts after br0 has its IP address (avoids "unknown interface br0" race)
  systemd.services.dnsmasq.after = ["network-addresses-br0.service"];
  systemd.services.dnsmasq.requires = ["network-addresses-br0.service"];

  boot.loader.systemd-boot.enable = true;

  nix.settings.substituters = lib.mkBefore ["http://omen:5000"];

  topology.self = {
    deviceType = "router";
    icon = "devices.router";
    hardware.info = "Mini-PC · 4-port NIC";
  };
}
