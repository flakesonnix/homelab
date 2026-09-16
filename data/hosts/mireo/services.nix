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
    # secrets.enable = true;  # Enable with sops-nix templated config

    # Keep empty in repo; set locally (ideally via sops-nix template).
    openFirewall = false; # NOTE: Easybell RTP needs 20000-50000, see module TODO
    phones = {};
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
}
