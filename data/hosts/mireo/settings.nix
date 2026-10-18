{
  lib,
  pkgs,
  ...
}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  # All owner keys: 5× github.com/flakesonnix.keys + p53-local omen key
  # + helianthus deploy key. Same set on every host with SSH.
  lucy.base.sshKey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOgPFwTysg5vOZ77Zqo9AehacYvO4iTm/T4QTy7MtfD2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzrW5cHMre50s8jFSbG6Yzg2TlQkKNQ59qRejIRUM0T"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSg7uG+/7pn6biGGzHTynH7FZUu0YzhfurY0L5GW7Di"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMermWS2Yxd5lthm6QpCxooP08ppv2+MJxYbHhoBYCz"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOppWJbYYY/Uwy2x4fb5RUUW+VLzLkRODyiha6QRM/tW lucy@omen"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrxXlvevZfbBd5Ey07hahyXQYrDjk/0I7mrERillcHZ helianthus@nixos"
  ];

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
  # FritzBox IPv6 (Diagnose 2026-10-10, live auf mireo verifiziert):
  #   WAN-GUAs kommen per SLAAC (2a02:3102:4ce0:6700::/64, wechselt bei
  #   Reconnects) + FritzBox-ULA (fd0b:f7ef:4ed5::/64). Der DHCPv6-Client
  #   (IA_NA + IA_PD, s.u.) bekommt KEINE Antwort: /var/lib/systemd/network
  #   bleibt leer, kein Lease — d.h. Entweder FritzBox-DHCPv6-Server aus
  #   oder keine PD. Hausaufgabe in der FritzBox (Heimnetz → Netzwerk →
  #   Netzwerkeinstellungen → IPv6): DHCPv6-Server AN + Präfix-Delegation
  #   für nachgelagerte Router (braucht ISP-Präfix kürzer als /64).
  #   Sobald PD landet, bekommt br0 automatisch ein GUA-/64 (s.u.) und
  #   dnsmasq kündigt es per RA an (constructor:br0) — kein Deploy nötig.
  # WAN läuft daneben mit statischem IPv4. No IPv6SendRA in networkd —
  # dnsmasq owns RA.
  # NOTE: br0 has IPv6Forwarding=true, which flips net.ipv6.conf.all.forwarding
  # to router mode. Under forwarding the kernel ignores RAs with accept_ra=1,
  # so WAN lives purely on SLAAC (renewed by FritzBox RAs). IPv4, ULA,
  # DHCPv4/DNS on br0 are unaffected either way.
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp4s0";
    address = ["192.168.178.25/24"];
    routes = [
      {
        Gateway = "192.168.178.1";
      }
    ];
    networkConfig = {
      DNS = ["9.9.9.9" "1.1.1.1"];
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
    # Static ULA = das stabile LAN-v6 (DNS-AAAA + DHCPv6 bauen darauf).
    # Ein FritzBox-PD-GUA landet hier automatisch daneben, sobald die
    # FritzBox delegiert (s. WAN-Kommentar); dnsmasq kündigt dann beide
    # Präfixe per RA an (constructor:br0). HE routed LAN entfernt
    # 2026-10-10 (VPS-unabhängiges v6 via NAT66, s.u.).
    address = ["10.8.0.1/24" "fd00:cafe:1::1/64"];
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

  # --- NAT66 outbound (primärer v6-Egress, VPS-unabhängig) ---
  # Masquerade LAN ULA behind whatever GUA is currently on enp4s0.
  # Prefix-change-proof (no hardcoded GUA). Falls FritzBox-PD je landet,
  # geht das delegierte GUA nativ raus (längeres Präfix schlägt NAT), ULA
  # bleibt per NAT66 erreichbar. Native nftables (networking.nat is v4-only).
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
  # (dnsmasq host-records; AdGuard filtert davor, gleiche Namen), der Traffic geht
  # (VM-Firewalls droppen :80) — die Caddy-VHosts bekamen nie Traffic.
  # Deshalb wird LAN-HTTP an LAN-Ziele transparent auf Caddy (:80)
  # umgebogen; der Host-Header bleibt erhalten, Caddy routet per Name.
  # Scope: nur br0-Eingang, nur Ziele in 10.8.0.0/24 (Internet-Traffic
  # und wg0 unberührt). Ausnahme 10.8.0.7 (sshkeys serviert :80 nativ).
  # Ping/SSH/DNS-Verhalten ändert sich nicht (nur TCP/80).
  # Diagnose 2026-09-16: Regel feuerte NIE — p53/VMs sind L2-benachbart
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

  # --- USB audio interface for MPD (host ALSA, no VM) ---
  # Behringer Xenyx 302USB (TI PCM2902, 08bb:2902): default ALSA nodes
  # are already root:audio, the mpd user just joins the audio group
  # (see modules/nixos/mpd.nix). No manual udev rule needed.

  # --- libvirtd (virt-manager remote target, Weg A) ---
  # Desktop-Client (p53) verbindet via qemu+ssh://root@10.8.0.1/system.
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

  # --- dnsmasq: DHCP + DNS for LAN (br0) ---
  # DNS from a single shared map (hosts/mireo/vm-ips.nix): the same
  # file feeds the microVM specs, so declare a VM IP once and its
  # home.arpa names appear automatically. Plus mireo itself.
  # DHCP clients resolve via their lease names.
  # NOTE (2026-10-04): dnsmasq stays authoritative for LAN DHCP+DNS.
  # AdGuard Home (dns VM, 10.8.0.30) is only a filtering frontend
  # (blocklists) — DHCP advertises it first, host second as fallback.
  services.dnsmasq = let
    lanDomain = "home.arpa";
    staticHosts =
      (import ../../../hosts/mireo/vm-ips.nix)
      // {
        mireo = "10.8.0.1";
        # TLS terminates on the host, not on the Sync guest (.31).
        fxsync = "10.8.0.1";
      };
  in {
    enable = true;
    settings = {
      interface = "br0";
      bind-interfaces = true;
      # /etc/hosts NICHT servieren (Diagnose 2026-09-14): NixOS trägt dort
      # 127.0.0.2 <hostname> ein, dnsmasq hätte `mireo` sonst doppelt
      # beantwortet (10.8.0.1 + 127.0.0.2) und `ping mireo` landet auf
      # localhost. Alle statischen Namen kommen aus host-record unten.
      no-hosts = true;
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
      # KEINE auth-zone/auth-server (Diagnose 2026-10-10, live bisectet):
      # dnsmasq 2.93 bindet TFTP auf der auth-server-IPv4 dann NICHT mehr
      # (10.8.0.1:69 fehlt, DNS/DHCP unberührt) — PXE wäre tot. Die
      # SOA/NS-Apex-Kosmetik ist den funktionierenden PXE-Boot nicht wert;
      # Namen kommen weiter aus host-record/DHCP/CNAME.
      # Service aliases (CNAME; target must be known to dnsmasq, so it
      # follows automatically if the target IP ever moves).
      cname = [
        "prometheus.home.arpa,grafana.home.arpa"
        "media.home.arpa,jellyfin.home.arpa"
        "adguard.home.arpa,dns.home.arpa"
      ];
      # NOTE (dropped 2026-09-16): UCS/AD is gone (libvirt domain ucs5.0
      # retired, no replacement). The AD SRV records lived here; if a new
      # directory ever returns, re-add them scoped to its name.
      dhcp-authoritative = true;
      enable-ra = true;
      dhcp-range = [
        "10.8.0.100,10.8.0.199,255.255.255.0,24h"
        # RA/SLAAC for every prefix on br0 (ULA + FritzBox-PD-GUA, falls
        # die FritzBox je delegiert — landet automatisch, kein Deploy).
        # NOTE: dnsmasq has NO `ra-stateful` flag (it fails with
        # "bad dhcp-range"): a bare `::,constructor:…` range is
        # stateless-only; stateful needs an explicit address range below
        # (dnsmasq then sets the RA managed bit automatically).
        "::,constructor:br0,ra-stateless,64,24h"
        # Stateful DHCPv6 on the static ULA (works independent of PD).
        # (HE routed LAN entfernt 2026-10-10, VPS-unabhängiges v6.)
        "fd00:cafe:1::100,fd00:cafe:1::1ff,64,24h"
      ];
      dhcp-option = [
        "option:router,10.8.0.1"
        # AdGuard (filtering frontend) first, host second: clients get
        # adblock via .30 and keep resolving (unfiltered) if the dns VM
        # is ever down. glibc falls through on timeout/refused.
        "option:dns-server,10.8.0.30,10.8.0.1"
        # NTP server (chrony VM, hosts/mireo/ntp-microvm.nix, UDP 123).
        "option:ntp-server,10.8.0.11"
        # Same explicitly for DHCPv6 + RA (RDNSS/DNSSL): without this,
        # clients only learn the link-local address via RA default, which
        # some stubs can't use (missing %iface scope). ULA is static.
        "option6:dns-server,[fd00:cafe:1::1]"
        "option6:domain-search,home.arpa"
      ];
      # Static IPs via DHCP reservations (not on-guest statics): every
      # homelab service keeps its vm-ips.nix address, but dnsmasq hands it
      # out, so IPs stay centrally managed in one file. Guest MACs are
      # deterministic (02:00:00:10:08:XX from the last octet — same formula
      # as hosts/mireo/microvm-base.nix). Format MAC,IP,name: dnsmasq pins
      # the IP AND serves the DNS name for the lease (short + home.arpa via
      # expand-hosts above; host-record below keeps AAAA + pre-lease A).
      # Reservations live outside the dynamic pool (10.8.0.100-.199), so no
      # collisions. (UCS reservation dropped with UCS itself, 2026-09-16.)
      dhcp-host =
        lib.mapAttrsToList (
          name: ip: let
            lastOctet = lib.toInt (lib.last (lib.splitString "." ip));
            hex = n: builtins.elemAt ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"] n;
          in "02:00:00:10:08:${hex (builtins.div lastOctet 16)}${hex (lib.mod lastOctet 16)},${ip},${name}"
        ) (import ../../../hosts/mireo/vm-ips.nix)
        # Freifunk box (real hardware, not a microVM): pins its current .193
        # so monitoring/DNS stay stable. Named ff-bb — its own hostname is
        # "mireo", which collides with ours (seen 2026-10-04 in leases).
        ++ ["44:d4:37:8b:d8:69,10.8.0.193,ff-bb"];
      # --- PXE boot (dnsmasq-nativ, GRUB lädt NixOS Xfce + netboot.xyz-Fallback) ---
      # Klassische PXE-ROMs laden iPXE per TFTP (BIOS: undionly.kpxe,
      # UEFI: snp.efi). iPXE-Clients (Option 175) laden das HTTP-Menü:
      # NixOS chainloadet dort GRUB je Plattform, netboot.xyz bleibt als
      # Fallback erreichbar. Nur GRUB lädt Kernel+große initrd per HTTP;
      # iPXE lädt die initrd nie selbst (contiguous-lowmem-Limit).
      # Normale Clients kriegen keinen Dateinamen (ungetaggte dhcp-boot
      # fehlt absichtlich).
      # Payload bauen + syncen (kein Build bei jedem mireo-Switch!):
      #   nix build .#pxe-desktop-boot   (→ ./result: bzImage/initrd/grub*/ *.ipxe)
      #   scp result/* root@10.8.0.1:/data/pxe/   (+ boot/grub rekursiv)
      # Quelle: hosts/pxe-desktop/ (netboot-base + Xfce, ohne ISO-Kette).
      # Ablauf: Firmware → iPXE-Menü → GRUB → bzImage + initrd (HTTP).
      # Secure Boot: grub.pxe/grubx64.efi unsigniert → auf physischen Zielen aus.
      # WICHTIG: tag:ipxe-Regel MUSS als letzte stehen — dnsmasq nimmt bei
      # mehreren passenden dhcp-boot-Zeilen die letzte (iPXE-Clients matchen
      # zugleich client-arch 0 UND Option 175; Diagnose 2026-09-14: mit
      # ipxe-Regel zuerst luden sie endlos undionly.kpxe neu).
      dhcp-match = [
        "set:bios,option:client-arch,0"
        "set:efi-bc,option:client-arch,7"
        "set:efi64,option:client-arch,9"
        "set:ipxe,175"
      ];
      dhcp-boot = [
        "tag:bios,undionly.kpxe,,10.8.0.1"
        "tag:efi-bc,snp.efi,,10.8.0.1"
        "tag:efi64,snp.efi,,10.8.0.1"
        "tag:ipxe,http://10.8.0.1/boot/menu.ipxe"
      ];
      enable-tftp = true;
      # Mutable Ablage (aus `nix build .#pxe-desktop-boot` gesynct: ipxe- +
      # grub-Binaries, boot/grub/grub.cfg); Caddy serviert /boot/* daraus per
      # HTTP (s.u.). Tmpfiles-Regel unten legt das Verzeichnis an.
      tftp-root = "/data/pxe";
      # Missing optional /data must not take DHCP/DNS down with TFTP.
      tftp-no-fail = true;
      # Everyone else gets dynamic addresses via DHCPv4/DHCPv6. dnsmasq
      # serves DNS names for its leases automatically, so clients stay
      # reachable as <hostname>.home.arpa.
      host-record =
        lib.mapAttrsToList (name: ip: let
          # ULA mirrors the IPv4 last octet, same as microvm-base.nix
          # assigns on the guest (10.8.0.N -> fd00:cafe:1::N).
          lastOctet = lib.last (lib.splitString "." ip);
        in "${name}.${lanDomain},${name},${ip},fd00:cafe:1::${lastOctet}")
        staticHosts
        # Freifunk box as ff-bb (v4 only — no known ULA; see dhcp-host).
        ++ ["ff-bb.${lanDomain},ff-bb,10.8.0.193"]
        # Status page vanity name (points at the uptime-kuma VM; the
        # transparent :80 redirect + Caddy redir below route it to
        # /status/homelab — same pattern as the other webUIs).
        ++ ["status.${lanDomain},status,10.8.0.9,fd00:cafe:1::9"];
      server = ["9.9.9.9" "1.1.1.1" "2620:fe::9" "2606:4700:4700::1111"];
    };
  };

  # AdGuard normally maps VM names directly to their guest IPs. Keep the
  # HTTPS service name on Caddy's host in this resolver as well.
  microvm.vms.dns.config.networking.hosts = {
    "10.8.0.31" = lib.mkForce [];
    "fd00:cafe:1::31" = lib.mkForce [];
    "10.8.0.1" = ["fxsync.home.arpa" "fxsync"];
    "fd00:cafe:1::1" = ["fxsync.home.arpa" "fxsync"];
  };

  # --- Caddy: name-based reverse proxy on port 80 for all LAN web UIs ---
  # One entrypoint: http://<name>.home.arpa (DNS from dnsmasq above).
  # The http:// prefix disables Caddy's automatic HTTPS — no public CA
  # issues certs for .home.arpa (RFC 8375). Sync below uses internal TLS
  # and explicit source filtering: the public edge also reaches Caddy.
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
      # IP from vm-ips.nix (single source) instead of a literal like above.
      uptime-kuma = "${(import ../../../hosts/mireo/vm-ips.nix).uptime-kuma}:3001";
      jellyfin = "${(import ../../../hosts/mireo/vm-ips.nix).jellyfin}:8096";
      lldap = "${(import ../../../hosts/mireo/vm-ips.nix).lldap}:17170";
      pocket-id = "${(import ../../../hosts/mireo/vm-ips.nix).pocket-id}:1411";
      # Alias vhost (same target as jellyfin; DNS CNAME above).
      media = "${(import ../../../hosts/mireo/vm-ips.nix).jellyfin}:8096";
      # Kodi music box web UI (Chorus) + JSON-RPC over HTTP.
      # Mopidy web client (Iris on localhost, LAN-only via Caddy).
      music = "127.0.0.1:6680";
      # Homelab dashboard (Homepage).
      dash = "${(import ../../../hosts/mireo/vm-ips.nix).dash}:8082";
      # AdGuard Home (filtering + stats UI; DHCP/DNS authoritative: dnsmasq).
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
    # PXE-Netboot-Payload (NixOS Xfce, siehe dnsmasq oben): statische
    # Dateien aus /data/pxe unter http://10.8.0.1/boot/* (IP-Literal, damit
    # iPXE kein DNS braucht). Alle anderen Pfade auf der IP bleiben 404
    # wie ohne diesen VHost (Caddy-Default für unbekannte Sites).
    pxeBoot = {
      "http://10.8.0.1" = ''
        handle /boot/* {
          uri strip_prefix /boot
          root * /data/pxe
          file_server
        }
      '';
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
      // lib.mapAttrs' (name: cfg: lib.nameValuePair name {extraConfig = cfg;}) statusRedir
      // lib.mapAttrs' (name: cfg: lib.nameValuePair name {extraConfig = cfg;}) pxeBoot
      // {
        "https://fxsync.home.arpa".extraConfig = ''
          tls internal
          # Check the socket peer, never a caller-supplied forwarded address.
          @lan remote_ip 127.0.0.1 ::1 10.8.0.0/24 fd00:cafe:1::/64
          handle @lan {
            reverse_proxy ${(import ../../../hosts/mireo/vm-ips.nix).fxsync}:5000
          }
          handle {
            respond 403
          }
        '';
      };
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/ee576a43-066a-4e85-901d-2f03d618bea8";
    fsType = "ext4";
    options = ["defaults" "nofail"];
  };

  systemd.tmpfiles.rules = [
    "Z /data 0755 lucy users - -"
    # PXE-Netboot-Ablage (aus `nix build .#pxe-desktop-boot`: bzImage/initrd,
    # grub.pxe/grubx64.efi/boot-grub-cfg/*.ipxe, per scp hierher syncen;
    # Caddy serviert /boot/*, dnsmasq-TFTP-root ist das Verzeichnis selbst).
    "d /data/pxe 0755 root root - -"
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
      /data 10.8.0.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100,insecure,mountpoint)
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
  # LAN-only services (NFS /data, dnsmasq DHCP/DNS, Avahi) stay bound to
  # br0 / 10.8.0.0/24 and are NOT reachable via wg0 (firewall below allows
  # only the published ports; Avahi is pinned to br0+lo).
  # Private key via `sops hosts/mireo/secrets.yaml`, peer key in
  # `hosts/nyagate/secrets.yaml`. After deploy: `wg show wg0` (both ends).
  # v6 läuft NATIV via FritzBox (ULA+NAT66, PD-GUA falls delegiert) —
  # wg0 trägt nur 10.66.0.1/32-Transit (kein 2000::/3 mehr, HE entfernt
  # 2026-10-10). Public-Inbound (80/443/25565) kommt weiter per DNAT über
  # den Tunnel (v4).
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
        allowedIPs = ["10.66.0.1/32"];
        persistentKeepalive = 25;
      }
    ];
  };

  # WireGuard handshake responses (mireo initiates out, but keep the port open
  # so the tunnel survives keepalive gaps / nyagate-initiated handshakes).
  networking.firewall.allowedUDPPorts = [51820];

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
