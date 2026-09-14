# Host-specific settings for nyagate (remote QEMU server, db210.org).
# Network + bootloader values imported from new/configuration.nix.
{
  lib,
  pkgs,
  ...
}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@nyagate";

  networking.hostName = "nyagate";

  # Static IPv4 (Hetzner-style /32 + gateway route).
  networking.useDHCP = false;
  networking.interfaces.eth0 = {
    ipv4.addresses = [
      {
        address = "188.220.148.24";
        prefixLength = 32;
      }
    ];
  };
  networking.defaultGateway = {
    address = "10.0.0.1";
    interface = "eth0";
  };
  networking.nameservers = ["1.1.1.1" "8.8.8.8" "2001:4860:4860::8888" "2001:4860:4860::8844"];

  # --- Natives IPv6 vom Provider (2a13:d200:11:1::/64, GW fd00::1) ---
  # Nur für nyagate selbst (Outbound ok, GW statisch via gateway-neigh unten).
  # Downstream läuft über HE (s. oben), nicht nativ (Provider-L2 kaputt).
  # /128, damit kein On-Link-/64 den WG-Routen in die Quere kommt.
  # Muster wie v4 (/32 + GW ausserhalb).
  networking.interfaces.eth0.ipv6.addresses = [
    {
      address = "2a13:d200:11:1::1";
      prefixLength = 128;
    }
  ];
  networking.defaultGateway6 = {
    address = "fd00::1";
    interface = "eth0";
  };
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # --- Statischer Nachbar-Eintrag fürs Provider-Gateway (NDP-Flap-Workaround) ---
  # Diagnose 2026-09-14: fd00::1 fällt auf INCOMPLETE (Gateway beantwortet NS
  # nur sporadisch — Nachbar-VMs spammen ebenfalls im Sekundentakt), danach
  # stirbt alles Weitergeleitete mit addr-unreachable. MAC 0a:a9:f2:06:74:45
  # wurde per REACHABLE-Eintrag verifiziert; statisch braucht es gar kein NDP.
  # ACHTUNG: Bei Provider-Failover (MAC-Wechsel) hier anpassen, sonst Blackhole.
  # allmulticast/promisc: ndppd muss fremde Solicited-Node-Gruppen (z.B.
  # ff02::1:ff00:2 für Downstream-Adressen) sehen — der NIC-Multicastfilter
  # und vSwitch-MLD-Snooping schlucken sie sonst, der Proxy bleibt taub
  # (tcpdump sieht sie nur dank eigenem Promiscuous-Modus). Diagnose 16:46:
  # NS für ::2 kommen rein, null Advertisements gehen raus.
  systemd.services.gateway-neigh = {
    description = "Static neighbor entry for provider gateway fd00::1";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.iproute2];
    script = ''
      ip -6 neigh replace fd00::1 lladdr 0a:a9:f2:06:74:45 dev eth0 nud permanent
      ip link set dev eth0 allmulticast on
      ip link set dev eth0 promisc on
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # --- HE Tunnelbroker 6in4 (Tunnel ID 1039084, Produktv-Pfad) ---
  # Natives Downstream ist unzustellbar (doppelte Provider-MAC b2:3d:66 auf
  # shared L2 -> NDP-Unicast zu uns unzuverlässig, Proxy-Antworten wirkungslos).
  # HE reitet auf gesundem v4 und umgeht das komplett.
  # Tunnel-Link: 2001:470:1f14:54f::2/64 <-> ::1, Routed LAN: 2001:470:1f15:54f::/64.
  # NICHT via systemd.netdev: networkd (261) lädt 10-he-ipv6.netdev kommentarlos
  # nie (224 Debug-Zeilen, null Erwähnung; manuelles `ip tunnel` geht sofort).
  # Deshalb expliziter oneshot mit denselben Befehlen.
  # Routing: HE-Default Metrik 512 (primär), nativer Default 1024 (Fallback,
  # greift wenn he-tunnel gestoppt ist und die HE-Route mitnimmt).
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;

  systemd.services.he-tunnel = {
    description = "HE 6in4 SIT tunnel (Tunnel ID 1039084)";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.iproute2];
    script = ''
      ip tunnel del he-ipv6 2>/dev/null || true
      ip tunnel add he-ipv6 mode sit remote 216.66.84.46 local 188.220.148.24 ttl 255
      ip link set he-ipv6 up mtu 1480
      ip addr add 2001:470:1f14:54f::2/64 dev he-ipv6
      ip -6 route replace default via 2001:470:1f14:54f::1 dev he-ipv6 metric 512
    '';
    preStop = ''
      ip -6 route del default via 2001:470:1f14:54f::1 dev he-ipv6 metric 512 2>/dev/null || true
      ip addr del 2001:470:1f14:54f::2/64 dev he-ipv6 2>/dev/null || true
      ip link set he-ipv6 down 2>/dev/null || true
      ip tunnel del he-ipv6 2>/dev/null || true
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # --- sops-nix secrets (WireGuard private key) ---
  # Prerequisite: age key at /etc/sops/age/keys.txt BEFORE first activation
  # with this enabled (deployed 2026-09-14), or activation fails.
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/nyagate/secrets.yaml;
  };

  sops.secrets."wireguard/nyagate-private-key" = {};

  # --- WireGuard transit to home LAN (mireo, 10.8.0.1) ---
  # Transit network 10.66.0.0/30: nyagate .1, mireo .2. Inbound ONLY:
  # public 80/443 (reverse proxy on mireo) + 25565/tcp+udp (Minecraft Java)
  # + 19132/udp (Geyser Bedrock, ~/mcserver auf mireo)
  # are DNAT'd through the tunnel, SNAT'd back so the return path stays
  # symmetric. No 0.0.0.0/0 in allowedIPs — default route stays local.
  # v6: HE routed LAN 2001:470:1f15:54f::/64 hängt hinter mireo (br0 ::1),
  # nyagate routet es via wg0 (WireGuard setzt die Route aus allowedIPs).
  networking.wireguard.interfaces.wg0 = {
    ips = ["10.66.0.1/30"];
    listenPort = 51820;
    # sops-nix renders this secret to /run/secrets/<name> at activation
    # (never in the Nix store).
    privateKeyFile = "/run/secrets/wireguard/nyagate-private-key";
    peers = [
      {
        name = "mireo";
        publicKey = "SKNUqLUwDlpoSi1W588BiRGYmFjaIOXHdaJ898T8C2E=";
        allowedIPs = ["10.66.0.2/32" "2001:470:1f15:54f::/64"];
        persistentKeepalive = 25;
      }
    ];
  };

  networking.firewall.allowedUDPPorts = [51820 25565 19132];
  networking.firewall.allowedTCPPorts = [80 443 25565];

  # v6-Forward wg0<->he-ipv6 fürs HE-LAN (FORWARD läuft über
  # nixos-filter-forward ohne v6-Accepts; v4 geht nur dank NAT-Modul).
  # Nur das HE-/64 in beide Richtungen (echtes Ende-zu-Ende-v6), v4-Policy bleibt.
  # MSS-Clamp: Doppel-Tunnel (WG 1420 + SIT 1480) — ohne hängen große Seiten.
  networking.firewall.extraCommands = ''
    ip6tables -w -I FORWARD 1 -i wg0 -o he-ipv6 -s 2001:470:1f15:54f::/64 -j ACCEPT
    ip6tables -w -I FORWARD 2 -i he-ipv6 -o wg0 -d 2001:470:1f15:54f::/64 -j ACCEPT
    iptables -w -I INPUT 1 -p 41 -s 216.66.84.46 -j ACCEPT
    # NDP für eigene Adressen/DAD muss den Kernel erreichen.
    ip6tables -w -I INPUT 1 -p icmpv6 --icmpv6-type neighbour-solicitation -j ACCEPT
    ip6tables -w -I INPUT 2 -p icmpv6 --icmpv6-type neighbour-advertisement -j ACCEPT
    ip6tables -w -t mangle -A FORWARD -i wg0 -o he-ipv6 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340
    ip6tables -w -t mangle -A FORWARD -i he-ipv6 -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340
  '';
  networking.firewall.extraStopCommands = ''
    ip6tables -w -D FORWARD -i wg0 -o he-ipv6 -s 2001:470:1f15:54f::/64 -j ACCEPT || true
    ip6tables -w -D FORWARD -i he-ipv6 -o wg0 -d 2001:470:1f15:54f::/64 -j ACCEPT || true
    iptables -w -D INPUT -p 41 -s 216.66.84.46 -j ACCEPT || true
    ip6tables -w -D INPUT -p icmpv6 --icmpv6-type neighbour-solicitation -j ACCEPT || true
    ip6tables -w -D INPUT -p icmpv6 --icmpv6-type neighbour-advertisement -j ACCEPT || true
    ip6tables -w -t mangle -D FORWARD -i wg0 -o he-ipv6 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 || true
    ip6tables -w -t mangle -D FORWARD -i he-ipv6 -o wg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340 || true
  '';

  # DNAT public ports into the tunnel (nyagate has the public IPv4).
  # NOTE: forwardPorts alone reicht NICHT — ohne SNAT käme das Paket mit
  # der echten Client-IP (z.B. 1.2.3.4) im Tunnel bei mireo an, und mireos
  # WireGuard verwirft alles, dessen Source nicht in seinen allowedIPs
  # (10.66.0.1/32, 2000::/3) steht. Symptom: conntrack SYN_SENT
  # [UNREPLIED], auf mireo kommt nichts an (Diagnose 2026-09-14).
  # Deshalb SNAT auf 10.66.0.1: symmetrischer Return-Path + WG-konform.
  # Nebeneffekt: Server im LAN sehen Externe als 10.66.0.1 (kein IP-Ban
  # pro Client möglich).
  networking.nat.extraCommands = ''
    iptables -w -t nat -A nixos-nat-post -o wg0 -d 10.66.0.2/32 -j SNAT --to-source 10.66.0.1
  '';
  networking.nat.extraStopCommands = ''
    iptables -w -t nat -D nixos-nat-post -o wg0 -d 10.66.0.2/32 -j SNAT --to-source 10.66.0.1 || true
  '';
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = ["wg0"];
    forwardPorts = [
      {
        sourcePort = 80;
        destination = "10.66.0.2:80";
        proto = "tcp";
      }
      {
        sourcePort = 443;
        destination = "10.66.0.2:443";
        proto = "tcp";
      }
      {
        sourcePort = 25565;
        destination = "10.66.0.2:25565";
        proto = "tcp";
      }
      {
        sourcePort = 25565;
        destination = "10.66.0.2:25565";
        proto = "udp";
      }
      {
        sourcePort = 19132;
        destination = "10.66.0.2:19132";
        proto = "udp";
      }
    ];
  };

  # BIOS boot on /dev/vda (QEMU guest, no EFI).
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  services.openssh.enable = true;

  # Installed as 26.11 — keep in sync with the initial install.
  system.stateVersion = "26.11";

  lucy.topology = {
    # Valid devices.* icons: cloud, cloud-server, desktop, laptop, nixos, router, switch.
    icon = "devices.cloud-server";
    hardware.info = "QEMU VM · db210.org";
  };
}
