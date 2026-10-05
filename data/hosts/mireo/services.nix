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
    # Fax scaffold: res_fax package + T.38 + [fax-in] + poller. Fax number
    # is the 2nd EPVPN extension (6983, see eventphone-fax client below);
    # Easybell later adds PSTN send/receive via faxDids + callerId there.
    # NOTE: package swap + dialplan need `systemctl restart asterisk` once.
    fax = {
      enable = true;
      inboxDir = "/data/fax/inbox";
    };
    faxSend = {
      enable = true;
      outboxDir = "/data/fax/outbox";
      queuedDir = "/data/fax/queued";
      # EPVPN trunk (hairpin tests to own numbers work; no PSTN dial-out).
      trunk = "eventphone-fax";
      registrar = "hg.eventphone.de";
      callerId = "6983"; # own fax extension
    };
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
      inboundExtension = "lucy"; # phone account name (PJSIP endpoint), NOT a dialplan ext!
      # EPVPN dialplan: 0-prefix specials (0310, 09…, 01999…) + 2100-7999
      # user range + emergency. Local numbers must avoid these (999/100/
      # phones do — no 0XXX/2XXX-7XXX locals, see module docs).
      localPatterns = ["_0X." "_[2-7]XXX" "110" "112"];
    };
    # Fax-only client (2nd EPVPN extension, no phone target): inbound to
    # its own number loops back into [fax-in]. Hairpin test: poller sends
    # to 6983, EPVPN routes back, ReceiveFAX lands in /data/fax/inbox.
    clients.eventphone-fax = {
      provider = "eventphone";
      username = "6983"; # 2nd Guru3 extension (fax number)
      passwordFile = "/run/secrets/voip/eventphone-fax";
      did = "6983";
      inboundExtension = null; # fax-only (see faxDids)
      faxDids = ["6983"];
    };
  };
  # sops.secrets."voip/easybell-main" = {};
  sops.secrets."voip/eventphone" = {};
  sops.secrets."voip/eventphone-fax" = {};

  # --- Minecraft server (Paper + Geyser, manual ~/mcserver dir) ---
  # Only the SERVICE is declarative (modules/nixos/minecraft.nix): the unit
  # runs `java -jar server.jar nogui` as lucy in /home/lucy/mcserver, world,
  # plugins and configs stay manual files. Public via nyagate DNAT
  # 25565/tcp+udp + 19132/udp -> wg0 (no host firewall change: wg0 rules +
  # trusted br0 already cover it). lucy manages the unit without root
  # (polkit): systemctl start/stop/restart/status minecraft.
  lucy.services.minecraft = {
    enable = true;
  };

  # --- Mopidy music server (host ALSA -> USB mixer, no VM) ---
  # Replaces the retired kodi music-box VM. Backends: local /data/Music,
  # Jellyfin, streams/radio. Clients: M.A.L.P. (Android), mpc CLI, Iris
  # web UI via Caddy (music.home.arpa). Spotify/SoundCloud/YouTube are
  # deliberately NOT wired yet (all fragile, see docs, Oct 2026).
  lucy.services.mopidy = {
    enable = true;
  };
  # Jellyfin password for the mopidy backend user. Bootstrap: create user
  # `mopidy` on Jellyfin (10.8.0.10), then replace the placeholder:
  #   sops set hosts/mireo/secrets.yaml '["mopidy"]["jellyfin-password"]' '"<pw>"'
  # Until then the jellyfin backend logs auth errors (others keep working).
  sops.secrets."mopidy/jellyfin-password" = {};

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
        group = "Public";
      };
      grafana-vhost = {
        type = "http";
        target = "http://grafana.home.arpa/";
        group = "Public";
      };
      grafana-public = {
        type = "http";
        target = "https://grafana.db210.org/";
        group = "Public";
      };
      yammat-public = {
        type = "http";
        target = "https://yammat.db210.org/";
        group = "Public";
      };
      monero-orport = {
        type = "port";
        target = "10.8.0.4";
        port = 9001;
        group = "Network";
      };
      minecraft = {
        type = "port";
        target = "10.66.0.2";
        port = 25565;
        group = "Network";
      };
      nfs = {
        type = "port";
        target = "10.8.0.1";
        port = 2049;
        group = "Network";
      };
      ssh-mireo = {
        type = "port";
        target = "10.8.0.1";
        port = 22;
        group = "Network";
      };
      mireo = {
        type = "ping";
        target = "10.8.0.1";
        group = "Network";
      };
      network-services = {
        type = "ping";
        target = "10.8.0.3";
        group = "Network";
      };
      monerod = {
        type = "ping";
        target = "10.8.0.4";
        group = "Network";
      };
      ntp = {
        type = "ping";
        target = "10.8.0.11";
        group = "Network";
      };
      fritzbox = {
        type = "ping";
        target = "192.168.178.1";
        group = "Network";
      };
      ff-bb = {
        type = "ping";
        target = "10.8.0.193";
        group = "Network";
      };
      internet = {
        type = "ping";
        target = "1.1.1.1";
        group = "Network";
      };
      nyagate = {
        type = "ping";
        target = "188.220.148.24";
        group = "Network";
      };
      lan-dns = {
        type = "dns";
        target = "grafana.home.arpa";
        group = "DNS";
      };
      uplink-dns = {
        type = "dns";
        target = "google.com";
        dnsServer = "1.1.1.1";
        group = "DNS";
      };
      lldap-ui = {
        type = "http";
        target = "http://10.8.0.12:17170/";
      };
      pocket-id = {
        type = "http";
        target = "http://10.8.0.13:1411/";
      };
      pocket-id-port = {
        type = "port";
        target = "10.8.0.13";
        port = 1411;
      };
      ldap-port = {
        type = "port";
        target = "10.8.0.12";
        port = 3890;
      };
      adguard = {
        type = "http";
        target = "http://10.8.0.30:3000/";
      };
      adguard-dns-port = {
        type = "port";
        target = "10.8.0.30";
        port = 53;
        group = "DNS";
      };
      lan-dns-adguard = {
        type = "dns";
        target = "music.home.arpa";
        dnsServer = "10.8.0.30";
        group = "DNS";
      };
      dash = {
        type = "http";
        target = "http://10.8.0.32:8082/";
      };
      mpd = {
        type = "port";
        target = "10.8.0.1";
        port = 6600;
        group = "Services";
      };
      music = {
        type = "http";
        target = "http://music.home.arpa/";
        group = "Services";
      };
      maps-osm = {
        type = "port";
        target = "10.8.0.27";
        port = 80;
      };
      network-services-http = {
        type = "port";
        target = "10.8.0.3";
        port = 80;
        group = "Network";
      };
      dns-host = {
        type = "ping";
        target = "10.8.0.30";
        group = "DNS";
      };
    };
  };
  sops.secrets."uptime-kuma/admin-password" = {};
  # LLDAP admin password -> shared read-only into the lldap guest; the
  # guest-side staging unit (root) copies it to tmpfs, so host ownership
  # stays default (no uid pinning needed). Key must exist in
  # hosts/mireo/secrets.yaml (verified present).
  sops.secrets."lldap/admin-password" = {};
  # Per-user passwords for the declarative seed (lldap-microvm.nix).
  sops.secrets."lldap/users/lucy" = {};
  # OIDC client secret for Grafana (created in the Pocket ID UI, step 3 of
  # hosts/mireo/pocket-id-microvm.nix bootstrap). Placeholder first:
  #   sops set hosts/mireo/secrets.yaml '["grafana"]["oidc-client-secret"]' '"CHANGEME"'
  # then the real secret after the OIDC client exists. Grafana keeps
  # anonymous Viewer access until then — no lockout while bootstrapping.
  sops.secrets."grafana/oidc-client-secret" = {};

  # ── Homelab platform secrets ──────────────────────
  # LDAP
  sops.secrets."ldap/replication-password" = {};
  # PostgreSQL databases
  sops.secrets."database/keycloak" = {};
  sops.secrets."database/nextcloud" = {};
  sops.secrets."database/immich" = {};
  sops.secrets."database/paperless" = {};
  sops.secrets."database/netbox" = {};
  sops.secrets."database/hydra" = {};
  sops.secrets."database/woodpecker" = {};
  sops.secrets."database/librenms" = {};
  sops.secrets."database/matrix" = {};
  # Keycloak
  sops.secrets."database/keycloak-admin" = {};
  # Devops
  sops.secrets."devops/woodpecker-secret" = {};
  sops.secrets."devops/netbox-secret" = {};
  sops.secrets."devops/hydra-secret" = {};
  # Registry
  sops.secrets."registry/auth" = {};
  # Matrix
  sops.secrets."matrix/registration_shared_secret" = {};
  sops.secrets."matrix/macaroon_secret" = {};
  sops.secrets."matrix/form_secret" = {};
  # ntfy
  sops.secrets."ntfy/admin-token" = {};
  # Backups
  sops.secrets."backup/postgres" = {};
  sops.secrets."backup/hydra" = {};
  sops.secrets."backup/nextcloud" = {};
  # Nextcloud admin
  sops.secrets."database/nextcloud-admin" = {};
  # Attic binary cache token secret (artifacts VM, environmentFile).
  sops.secrets."artifacts/attic-env" = {};
  # Management VM API tokens (least privilege: per-VM dir, not shared).
  # PLACEHOLDERS — mint real tokens in the LibreNMS/NetBox UIs, then:
  #   sops set hosts/mireo/secrets.yaml '["management"]["librenms-api-key"]' '"<token>"'
  #   sops set hosts/mireo/secrets.yaml '["management"]["netbox-api-token"]' '"<token>"'
  sops.secrets."management/librenms-api-key" = {};
  sops.secrets."management/netbox-api-token" = {};
}
