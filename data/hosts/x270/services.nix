{
  # --- sops-nix secrets (uncomment after running `nix run .#setup-sops`) ---
  # lucy.secrets = {
  #   enable = true;
  #   sopsFile = ../../../hosts/x270/secrets.yaml;
  # };

  services.asteriskLocal = {
    enable = false;
    # secrets.enable = true;  # Enable with sops-nix templated config

    # Keep empty in repo; set locally (ideally via sops-nix template).
    openFirewall = true;
    phones = {};
    extraExtensions = "";
  };

  # --- VoIP/SIP abstraction (Phase 2: live PJSIP trunk rendering) ---
  # Voice stack lives on x270 next to asteriskLocal; mireo/nyagate untouched.
  # Secrets: only sops KEY NAMES are referenced here; passwords live
  # encrypted in hosts/x270/secrets.yaml and decrypted in /run/secrets
  # (tmpfs, never in the Nix store). See docs/secrets.md ("VoIP secrets").
  # Trunk needs services.asteriskLocal.enable = true (PJSIP transport +
  # #includes). Password rotation: update sops, then
  #   systemctl restart voip-render-trunks && asterisk -rx 'core reload'
  # services.voip = {
  #   enable = true;
  #   localTest.enable = true; # needs services.asteriskLocal.enable = true; dial 999
  #   clients.easybell-main = {
  #     provider = "easybell";
  #     username = "K12345678"; # from the Easybell customer portal
  #     # sops-nix decrypts hosts/x270/secrets.yaml to this tmpfs path:
  #     passwordFile = "/run/secrets/voip/easybell-main";
  #     did = "00493012345"; # Stammnummer, E.164 without '+'
  #     contactUser = "493012345000"; # head number (Zentrale); falls back to did
  #     inboundExtension = "999"; # local target for inbound calls
  #     displayName = "Homelab"; # needs CLIP No Screening in my.easybell
  #   };
  # };
  # sops.secrets."voip/easybell-main" = {};

  hq.audio.streamTo = "";

  # Scraped by the grafana microvm on mireo (10.8.0.2)
  services.prometheus.exporters.node.enable = true;

  programs.noisetorch.enable = true;
}
