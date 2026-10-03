{
  lib,
  pkgs,
  ...
}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrxXlvevZfbBd5Ey07hahyXQYrDjk/0I7mrERillcHZ helianthus@nixos";
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
  # static IPv4. The delegated prefix is handed to br0 below; LAN RAs for
  # it came from dnsmasq (removed 2026-10-03, AdGuard sends ULA RAs only).
  # automatically). No IPv6SendRA in networkd.
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
    # Static ULA stays so LAN-local v6 keeps working even if the FritzBox
    # delegation ever fails.
    # HE routed LAN (via nyagate wg0, Tunnel ID 1039084): no RAs anymore
    # (dnsmasq removed 2026-10-03) — GUA-SLAAC degraded to FritzBox scope.
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
  # 19999 removed with netdata (dropped 2026-09-16); 9090 untouched.
  networking.firewall.interfaces.br0.allowedTCPPorts = [9090];

  # --- Transparent LAN :80 → Caddy (nftables REDIRECT) ---
  # Diagnose 2026-09-15: *.home.arpa löst DIREKT auf die VM-IPs auf
  # (AdGuard hosts-Einträge, vorher dnsmasq host-records), der Traffic geht
  # (VM-Firewalls droppen :80) — die Caddy-VHosts bekamen nie Traffic.
  # Deshalb wird LAN-HTTP an LAN-Ziele transparent auf Caddy (:80)
  # umgebogen; der Host-Header bleibt erhalten, Caddy routet per Name.
  # Scope: nur br0-Eingang, nur Ziele in 10.8.0.0/24 (Internet-Traffic
  # und wg0 unberührt). Ausnahme 10.8.0.7 (sshkeys serviert :80 nativ).
  # Ping/SSH/DNS-Verhalten ändert sich nicht (nur TCP/80).
  # Diagnose 2026-09-16: Regel feuerte NIE — x270/VMs sind L2-benachbart
  # (gleiche Bridge), bridged Traffic umgeht `ip`-nftables ohne
  # br_netfilter (Modul war nicht geladen, keine /proc/sys/net/bridge/*).
  # br_netfilter unten lädt es + schaltet den L3-Pfad an; FORWARD-Policy
  # ist accept, daher bleibt LAN-Verkehr unbehelligt (nur conntrack mehr).
  # Ohne das Modul landeten Browser (v4+v6) direkt auf VM-:80 im Drop.
  boot.kernelModules = ["br_netfilter"];
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
  };
  networking.nftables.tables.lan-http-redirect = {
    family = "ip";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "br0" tcp dport 80 ip daddr 10.8.0.0/24 ip daddr != 10.8.0.7 redirect to :80
      }
    '';
  };
  # v6-Gegenstück (ULA): ohne ihn hängt der Browser im Happy-Eyeballs-
  # Verlierer (VM-:80 gedroppt), statt über Caddy zu gehen. Ausnahme
  # fd00:cafe:1::7 = sshkeys (ULA-Mirror von .7, serviert :80 nativ).
  networking.nftables.tables.lan-http-redirect6 = {
    family = "ip6";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "br0" tcp dport 80 ip6 daddr fd00:cafe:1::/64 ip6 daddr != fd00:cafe:1::7 redirect to :80
      }
    '';
  };

  # --- USB passthrough for the Kodi music-box VM ---
  # Behringer Xenyx 302USB (TI PCM2902, 08bb:2902): QEMU usb-host needs
  # host-side access. microvm.nix sets up PCI permissions automatically,
  # but USB needs this manual rule (GROUP=kvm, same as upstream docs).
  # Must stay in sync with microvm.devices in hosts/mireo/kodi-microvm.nix.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="08bb", ATTR{idProduct}=="2902", GROUP="kvm"
  '';

  # --- libvirtd (virt-manager remote target, Weg A) ---
  # Desktop-Client (x270) verbindet via qemu+ssh://root@10.8.0.1/system.
  # microVMs (microvm.nix, systemd microvm@*) bleiben daneben bestehen und
  # erscheinen NICHT in virt-manager (andere Tech) — GUI nur für neue
  # libvirt-Gäste. Bridge br0 nutzen (NICHT virbr0/default-Netz): br0 ist
  # bereits trusted + AdGuard/DNS vorhanden. IPs statisch ausserhalb
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

  # lucy darf libvirt ohne Polkit-Agent verwalten (headless Server).
  # Diagnose 2026-09-14: qemu+ssh://lucy@10.8.0.1/system starb mit
  # "authentication unavailable: no polkit agent available to authenticate
  # action 'org.libvirt.unix.manage'". root geht auch ohne Regel.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage" && subject.user == "lucy") {
        return polkit.Result.YES;
      }
    });
  '';

  # --- LAN DHCP + DNS: AdGuard Home (dns VM, 10.8.0.30) ---
  # dnsmasq wurde 2026-10-03 durch AdGuard ersetzt (hosts/mireo/dns-microvm.nix):
  # DHCPv4-Leases + DNS-Records (A/AAAA/Aliase) werden dort aus
  # hosts/mireo/vm-ips.nix generiert (single source bleibt).
  # Bewusst entfallen: PXE/iPXE (Ersatz: iVentoy via podman),
  # FritzBox-PD-RAs, HE-GUA-stateful-DHCPv6. Rollback = alte Generation deployen.

  # --- Caddy: name-based reverse proxy on port 80 for all LAN web UIs ---
  # One entrypoint: http://<name>.home.arpa (DNS from the AdGuard VM above).
  # The http:// prefix disables Caddy's automatic HTTPS — no public CA
  # issues certs for .home.arpa (RFC 8375). WAN port 80 stays closed by
  # the default firewall (only br0 is trusted), so this is LAN-only.
  # Direct ports (CUPS :631 IPP, …) keep working untouched.
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
      # IP from vm-ips.nix (single source) instead of a literal like above.
      uptime-kuma = "${(import ../../../hosts/mireo/vm-ips.nix).uptime-kuma}:3001";
      jellyfin = "${(import ../../../hosts/mireo/vm-ips.nix).jellyfin}:8096";
      lldap = "${(import ../../../hosts/mireo/vm-ips.nix).lldap}:17170";
      pocket-id = "${(import ../../../hosts/mireo/vm-ips.nix).pocket-id}:1411";
      # Alias vhost (same target as jellyfin; DNS CNAME above).
      media = "${(import ../../../hosts/mireo/vm-ips.nix).jellyfin}:8096";
      # Kodi music box web UI (Chorus) + JSON-RPC over HTTP.
      kodi = "${(import ../../../hosts/mireo/vm-ips.nix).kodi}:8080";
      # Homelab dashboard (Homepage).
      dash = "${(import ../../../hosts/mireo/vm-ips.nix).dash}:8082";
      # AdGuard Home (DNS + DHCP server UI).
      adguard = "${(import ../../../hosts/mireo/vm-ips.nix).dns}:3000";
    };
    # Vanity URL for the declarative status page (302 to the real path so
    # the page's relative /api calls keep working — a rewrite would break
    # them). DNS: status.home.arpa host-record above.
    statusRedir = {
      "http://status.home.arpa" = "redir http://uptime-kuma.home.arpa/status/homelab 302";
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
      publicWebUIs
      // lib.mapAttrs' (name: cfg: lib.nameValuePair name {extraConfig = cfg;}) statusRedir;
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

  # netdata dropped 2026-09-16 (replaced by Grafana/Prometheus +
  # uptime-kuma + nixfleet agent). See git history for the old block.
  services.netdata.enable = false;

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
  # LAN-only services (NFS /data, AdGuard DHCP/DNS, Avahi) stay bound to
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
    allowedUDPPorts = [25565 19132];
  };

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
