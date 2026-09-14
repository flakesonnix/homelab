{
  lib,
  pkgs,
  ...
}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@mireo";

  # --- sops-nix secrets (WireGuard private key, future service secrets) ---
  # Prerequisite: age key deployed at /etc/sops/age/keys.txt BEFORE first
  # activation with this enabled, or activation fails. See docs/secrets.md.
  # Rollback: set enable = false and redeploy.
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/mireo/secrets.yaml;
  };

  sops.secrets."wireguard/mireo-private-key" = {};

  networking.hostName = "mireo";
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;

  systemd.network.enable = true;
  # FritzBox IPv6 (as of 2026-05-29):
  #   WAN addr:  2a02:3102:4c00:3b::1b5/64 (SLAAC, fallback)
  #   delegated: 2a02:3102:4cec:b500::/64  (DHCPv6 PD, assigned to br0 LAN)
  # WAN runs a DHCPv6 client (IA_NA address + IA_PD prefix) alongside the
  # static IPv4. The delegated prefix is handed to br0 below; dnsmasq keeps
  # sending the LAN RAs (constructor:br0 picks the delegated GUA up
  # automatically). No IPv6SendRA in networkd — dnsmasq owns RA.
  # NOTE: br0 has IPv6Forwarding=true, which flips net.ipv6.conf.all.forwarding
  # to router mode. Under forwarding the kernel ignores RAs with accept_ra=1,
  # so the WAN SLAAC address may disappear — the DHCPv6 IA_NA address replaces
  # it. IPv4, ULA, DHCPv4/DNS on br0 are unaffected either way.
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
      DHCP = "ipv6";
      DHCPPrefixDelegation = true;
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
    # Static ULA stays as fallback/seed so LAN-local v6 + dnsmasq constructor
    # keep working even if the FritzBox delegation ever fails.
    # HE routed LAN (via nyagate wg0, Tunnel ID 1039084): SLAAC kommt aus
    # dnsmasq constructor:br0 automatisch, sobald die Adresse hier liegt.
    address = ["10.8.0.1/24" "fd00:cafe:1::1/64" "2001:470:1f15:54f::1/64"];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6AcceptRA = false;
      LinkLocalAddressing = "ipv6";
      # Router mode for the delegated GUA (also flips all.forwarding, which is
      # what routes LAN<->WAN v6; firewall filterForward is off by default).
      IPv6Forwarding = true;
      # Take a /64 from the enp4s0 delegation (Assign=yes by default, EUI-64).
      # Announce is inert here (upstream requests PD, no networkd SendRA).
      DHCPPrefixDelegation = true;
    };
    dhcpPrefixDelegationConfig = {
      UplinkInterface = "enp4s0";
    };
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp4s0";
    internalInterfaces = ["br0"];
  };

  # --- NAT66 outbound (no PD from FritzBox, so no LAN GUA) ---
  # Masquerade LAN ULA behind whatever GUA is currently on enp4s0.
  # Prefix-change-proof (no hardcoded GUA), GUA passes through untouched
  # if PD ever lands. Native nftables (networking.nat is v4-only).
  # NOTE: br0's IPv6Forwarding only flips the per-link flag — LAN→WAN
  # forward needs all.forwarding=1 (was 0, v6 egress dead, 2026-09-14).
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  networking.nftables.enable = true;
  networking.nftables.tables.nat66 = {
    family = "ip6";
    content = ''
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "enp4s0" ip6 saddr fd00:cafe:1::/64 masquerade
      }
    '';
  };

  networking.firewall.trustedInterfaces = ["br0"];
  networking.firewall.interfaces.br0.allowedTCPPorts = [19999 9090];

  # --- libvirtd (virt-manager remote target, Weg A) ---
  # Desktop-Client (x270) verbindet via qemu+ssh://root@10.8.0.1/system.
  # microVMs (microvm.nix, systemd microvm@*) bleiben daneben bestehen und
  # erscheinen NICHT in virt-manager (andere Tech) — GUI nur für neue
  # libvirt-Gäste. Bridge br0 nutzen (NICHT virbr0/default-Netz): br0 ist
  # bereits trusted + dnsmasq/DNS vorhanden. IPs statisch ausserhalb
  # DHCP-Range (10.8.0.100-.199) wählen + in hosts/mireo/vm-ips.nix eintragen.
  # Risiko: libvirt 12.4 secrets-encryption-key/TPM-Bug (243/CREDENTIALS).
  # Recovery: rm /var/lib/libvirt/secrets/secrets-encryption-key + reboot.
  # deploy-rs nutzt switch-to-configuration direkt (toleranter als
  # nixos-rebuild-ng strict exit 4).
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";
    onShutdown = "shutdown";
    allowedBridges = ["br0"];
    qemu.vhostUserPackages = with pkgs; [virtiofsd];
  };

  # --- dnsmasq: DHCP + DNS for LAN (br0) ---
  # DNS from a single shared map (hosts/mireo/vm-ips.nix): the same
  # file feeds the microVM specs, so declare a VM IP once and its
  # home.arpa names appear automatically. Plus mireo itself.
  # DHCP clients resolve via their lease names.
  services.dnsmasq = let
    lanDomain = "home.arpa";
    staticHosts = (import ../../../hosts/mireo/vm-ips.nix) // {mireo = "10.8.0.1";};
  in {
    enable = true;
    settings = {
      interface = "br0";
      bind-interfaces = true;
      domain-needed = true;
      bogus-priv = true;
      # Local DNS domain (RFC 8375): <hostname>.home.arpa resolves for
      # DHCP leases (automatic), static host-records (FQDN first name
      # below) and short names (expand-hosts). local= keeps the whole
      # domain strictly local — never forwarded upstream. DHCP clients
      # also receive home.arpa as search domain automatically.
      domain = lanDomain;
      expand-hosts = true;
      local = "/${lanDomain}/";
      dhcp-authoritative = true;
      enable-ra = true;
      dhcp-range = [
        "10.8.0.100,10.8.0.199,255.255.255.0,24h"
        # RA/SLAAC for every prefix on br0 (ULA + HE routed GUA, FritzBox PD
        # falls je durch).
        # NOTE: dnsmasq has NO `ra-stateful` flag (it fails with
        # "bad dhcp-range"): a bare `::,constructor:…` range is
        # stateless-only; stateful needs an explicit address range below
        # (dnsmasq then sets the RA managed bit automatically).
        "::,constructor:br0,ra-stateless,64,24h"
        # Stateful DHCPv6 on the static ULA (works independent of PD)
        # + HE routed LAN (via nyagate wg0).
        "fd00:cafe:1::100,fd00:cafe:1::1ff,64,24h"
        "2001:470:1f15:54f::100,2001:470:1f15:54f::1ff,64,24h"
      ];
      dhcp-option = [
        "option:router,10.8.0.1"
        "option:dns-server,10.8.0.1"
      ];
      # No dhcp-host entries: all LAN clients get dynamic addresses
      # via DHCPv4/DHCPv6. dnsmasq serves DNS names for its leases
      # automatically, so clients stay reachable as <hostname>.home.arpa.
      host-record = lib.mapAttrsToList (name: ip: "${name}.${lanDomain},${name},${ip}") staticHosts;
      server = ["1.1.1.1" "9.9.9.9" "2606:4700:4700::1111" "2620:fe::9"];
    };
  };

  # --- Caddy: name-based reverse proxy on port 80 for all LAN web UIs ---
  # One entrypoint: http://<name>.home.arpa (DNS from dnsmasq above).
  # The http:// prefix disables Caddy's automatic HTTPS — no public CA
  # issues certs for .home.arpa (RFC 8375). WAN port 80 stays closed by
  # the default firewall (only br0 is trusted), so this is LAN-only.
  # Direct ports (CUPS :631 IPP, iVentoy PXE, …) keep working untouched.
  # Public edge (via nyagate DNAT 80/443 → wg0, firewall interfaces.wg0):
  # bare domains below get automatic TLS from Caddy. Prerequisite: A
  # records *.db210.org → 188.220.148.24 at the registrar, otherwise
  # Caddy keeps retrying ACME in the background (service stays up).
  services.caddy = let
    webUIs = {
      grafana = "10.8.0.2:3000";
      prometheus = "10.8.0.2:9090";
      yammat = "10.8.0.5:3000";
      cups = "10.8.0.6:631";
      sshkeys = "10.8.0.7:80";
      aptcache = "10.8.0.8:3142";
      netdata = "127.0.0.1:19999";
      iventoy = "127.0.0.1:26000";
    };
    publicWebUIs = {
      "yammat.db210.org" = "10.8.0.5:3000";
      "grafana.db210.org" = "10.8.0.2:3000";
    };
  in {
    enable = true;
    virtualHosts =
      lib.mapAttrs' (name: target:
        lib.nameValuePair "http://${name}.home.arpa" {
          extraConfig = "reverse_proxy ${target}";
        })
      webUIs
      // lib.mapAttrs' (name: target:
        lib.nameValuePair name {
          extraConfig = "reverse_proxy ${target}";
        })
      publicWebUIs;
  };

  # --- iVentoy PXE server (proxyDHCP mode, web UI :26000) ---
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.iventoy = {
    image = "docker.io/garybowers/iventoy:latest";
    # --privileged required: proxyDHCP mode needs raw sockets/BPF for DHCP+TFTP
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

  systemd.tmpfiles.rules = [
    "Z /data 0755 lucy users - -"
  ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    # mDNS stays LAN-only: never advertise/respond via wg0 (public edge).
    allowInterfaces = ["br0" "lo"];
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
      /data 10.8.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100,insecure)
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

  # --- WireGuard transit to public edge (nyagate VPS, db210.org) ---
  # Transit network 10.66.0.0/30: nyagate .1, mireo .2. This carries ONLY
  # explicitly published inbound traffic (DNAT'd on nyagate, SNAT'd back so
  # return path stays symmetric via the tunnel — no 0.0.0.0/0 AllowedIPs here,
  # which would hijack the default route and break LAN/NFS/IPv6/microVMs).
  # LAN-only services (NFS /data, dnsmasq DHCP/DNS, PXE, Avahi) stay bound to
  # br0 / 10.8.0.0/24 and are NOT reachable via wg0 (firewall below allows
  # only the published ports; Avahi is pinned to br0+lo).
  # Private key via `sops hosts/mireo/secrets.yaml`, peer key in
  # `hosts/nyagate/secrets.yaml`. After deploy: `wg show wg0` (both ends).
  # v6: global unicast (2000::/3) geht via wg0 -> nyagate HE-Tunnel raus.
  # ULA bleibt bewusst ausgenommen (weiter NAT66 via enp4s0 als Fallback).
  networking.wireguard.interfaces.wg0 = {
    ips = ["10.66.0.2/30"];
    listenPort = 51820;
    # sops-nix renders this secret to /run/secrets/<name> at activation
    # (never in the Nix store). `...` args above have no `config` here —
    # settings.nix is data merged by the framework, so use the static path.
    privateKeyFile = "/run/secrets/wireguard/mireo-private-key";
    peers = [
      {
        name = "nyagate";
        publicKey = "pKir9k3Af8ng24vW/vzoRkewoaMHdWysqxNX9xQbU0o=";
        endpoint = "188.220.148.24:51820";
        allowedIPs = ["10.66.0.1/32" "2000::/3"];
        persistentKeepalive = 25;
      }
    ];
  };

  # WireGuard handshake responses (mireo initiates out, but keep the port open
  # so the tunnel survives keepalive gaps / nyagate-initiated handshakes).
  networking.firewall.allowedUDPPorts = [51820];

  # --- Bevorzugte v6-Source fürs Tunnel-Routing (HE primär) ---
  # Diagnose 2026-09-14: Kernel wählt sonst die FritzBox-GUA als Source
  # (asymmetrisch: raus via WG/HE, zurück via FritzBox -> conntrack DROP).
  # Diese Route (Metrik 512) sticht die WireGuard-Route (1024) aus und pinnt
  # die HE-Adresse als Source. ULA/NAT66-Fallback unberührt.
  systemd.network.networks."40-wg0" = {
    matchConfig.Name = "wg0";
    routes = [
      {
        Destination = "2000::/3";
        PreferredSource = "2001:470:1f15:54f::1";
        Metric = 512;
      }
    ];
  };

  # Published services ONLY — must mirror nyagate's forwardPorts. Everything
  # else arriving via wg0 is dropped by default-deny.
  networking.firewall.interfaces.wg0 = {
    allowedTCPPorts = [80 443 25565];
    allowedUDPPorts = [25565];
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

  # Ensure dnsmasq starts after br0 exists (avoids "unknown interface" race)
  # Make dnsmasq restart on failure but not block NixOS activation (optional
  # runtime service — failure should not trigger deploy-rs rollback).
  systemd.services.dnsmasq.after = ["sys-devices-virtual-net-br0.device"];
  systemd.services.dnsmasq.bindsTo = ["sys-devices-virtual-net-br0.device"];
  systemd.services.dnsmasq.serviceConfig.Restart = "on-failure";
  systemd.services.dnsmasq.serviceConfig.RestartSec = "5s";

  boot.loader.systemd-boot.enable = true;

  lucy.topology = {
    deviceType = "router";
    icon = "devices.router";
    hardware.info = "Mini-PC · 4-port NIC";
  };

  # --- nixfleet control plane (M1: mireo runtime) ---
  lucy.nixfleet = {
    enable = true;
    role = "api";
    api = {
      port = 8443;
      # Copy to a GC-rooted derivation so the path survives after the
      # flake source is garbage-collected (direct flake-source references
      # like ../../../nixfleet/artifacts are build-time only and break at
      # runtime once `nix store gc` removes the source).
      artifactsDir = pkgs.runCommand "nixfleet-artifacts" {} ''
        mkdir -p $out
        cp ${../../../nixfleet/artifacts/manifest.json} $out/manifest.json
        cp ${../../../nixfleet/artifacts/ui.json} $out/ui.json
      '';
    };
    agent = {
      plugins = ["systemd" "journal" "metrics"];
    };
  };
}
