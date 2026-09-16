{
  # --- Voice stack (Asterisk PJSIP + services.voip abstraction) ---
  # Lives on mireo (always-on server). asteriskLocal + voip are ENABLED:
  # the next deploy starts Asterisk and registers 4309 at Eventphone.
  # Secrets: only sops KEY NAMES are referenced here; passwords live
  # encrypted in hosts/mireo/secrets.yaml and decrypted in /run/secrets
  # (tmpfs, never in the Nix store). See docs/secrets.md ("VoIP secrets").
  # No firewall changes: br0 is trusted, SIP/RTP are outbound-initiated.
  services.asteriskLocal = {
    enable = true;
    secrets.enable = true; # sops-template rendering (passwords stay out of the store)

    # Local SIP phones (softphones/IP phones register here, then dial
    # 999 = local test, 0310 = EPVPN announcement via trunk, 100 = hello-world).
    # Passwords live in hosts/mireo/secrets.yaml (asterisk.phones.<name>).
    openFirewall = false; # NOTE: Easybell RTP needs 20000-50000, see module TODO
    phones.lucy = {
      extension = "1001";
      passwordSecret = "asterisk/phones/lucy";
    };
    extraExtensions = "";
  };

  # Password rotation: update sops, then
  #   systemctl restart voip-render-trunks && asterisk -rx 'core reload'
  services.voip = {
    enable = true;
    localTest.enable = true; # dial 999 from any internal phone
    # clients.easybell-main = {
    #   provider = "easybell";
    #   username = "K12345678"; # from the Easybell customer portal
    #   # sops-nix decrypts hosts/mireo/secrets.yaml to this tmpfs path:
    #   passwordFile = "/run/secrets/voip/easybell-main";
    #   did = "00493012345"; # Stammnummer, E.164 without '+'
    #   contactUser = "493012345000"; # head number (Zentrale); falls back to did
    #   inboundExtension = "999"; # local target for inbound calls
    #   displayName = "Homelab"; # needs CLIP No Screening in my.easybell
    # };
    # Eventphone (per-event account from Guru3; transport UDP).
    # NOTE: event SIP has no dial-out — inbound + internal only.
    clients.eventphone = {
      provider = "eventphone";
      username = "4309"; # Guru3 extension/SIP username
      passwordFile = "/run/secrets/voip/eventphone";
      did = "4309"; # Guru3 extension number (client_uri + inbound match)
      inboundExtension = "999"; # local test ext
    };
  };
  # sops.secrets."voip/easybell-main" = {};
  sops.secrets."voip/eventphone" = {};

  # --- Declarative Uptime Kuma monitors (authoritative API sync) ---
  # Targets verified live 2026-09-16 (only 2xx/3xx + reachable hosts).
  # Skipped deliberately: x270 (roaming), notifications (no channel yet).
  services.uptime-kuma-sync = {
    enable = true;
    apiUrl = "http://10.8.0.9:3001";
    username = "lucy";
    passwordFile = "/run/secrets/uptime-kuma/admin-password";
    statusPage.enable = true; # public page /status/homelab (+ status.home.arpa)
    monitors = {
      grafana = {
        type = "http";
        target = "http://10.8.0.2:3000/";
      };
      prometheus = {
        type = "http";
        target = "http://10.8.0.2:9090/";
      };
      yammat = {
        type = "http";
        target = "http://10.8.0.5:3000/";
      };
      cups = {
        type = "http";
        target = "http://10.8.0.6:631/";
      };
      sshkeys = {
        type = "http";
        target = "http://10.8.0.7/";
      };
      jellyfin = {
        type = "http";
        target = "http://10.8.0.10:8096/";
      };
      uptime-self = {
        type = "http";
        target = "http://10.8.0.9:3001/";
      };
      uptime-vhost = {
        type = "http";
        target = "http://uptime-kuma.home.arpa/";
      };
      grafana-vhost = {
        type = "http";
        target = "http://grafana.home.arpa/";
      };
      grafana-public = {
        type = "http";
        target = "https://grafana.db210.org/";
      };
      yammat-public = {
        type = "http";
        target = "https://yammat.db210.org/";
      };
      aptcache = {
        type = "port";
        target = "10.8.0.8";
        port = 3142;
      };
      monero-orport = {
        type = "port";
        target = "10.8.0.4";
        port = 9001;
      };
      minecraft = {
        type = "port";
        target = "10.66.0.2";
        port = 25565;
      };
      nfs = {
        type = "port";
        target = "10.8.0.1";
        port = 2049;
      };
      ssh-mireo = {
        type = "port";
        target = "10.8.0.1";
        port = 22;
      };
      mireo = {
        type = "ping";
        target = "10.8.0.1";
      };
      network-services = {
        type = "ping";
        target = "10.8.0.3";
      };
      monerod = {
        type = "ping";
        target = "10.8.0.4";
      };
      ntp = {
        type = "ping";
        target = "10.8.0.11";
      };
      fritzbox = {
        type = "ping";
        target = "192.168.178.1";
      };
      internet = {
        type = "ping";
        target = "1.1.1.1";
      };
      nyagate = {
        type = "ping";
        target = "188.220.148.24";
      };
      lan-dns = {
        type = "dns";
        target = "grafana.home.arpa";
      };
      uplink-dns = {
        type = "dns";
        target = "google.com";
        dnsServer = "1.1.1.1";
      };
    };
  };
  sops.secrets."uptime-kuma/admin-password" = {};
}
