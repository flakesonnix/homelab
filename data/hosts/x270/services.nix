{
  # --- sops-nix secrets (Key via `nix run .#setup-sops` nach /etc/sops/age/keys.txt) ---
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/x270/secrets.yaml;
  };

  # Täglicher XMLTV-Guide für die Jellyfin-MicroVM (iptv-org/epg, host-seitig
  # gebaut, per SSH geschoben). API-Token liegt in hosts/x270/secrets.yaml
  # (jellyfin/epg-api-token), Key auf der VM als `epg-setup` angelegt.
  sops.secrets."jellyfin/epg-api-token" = {};
  services.epg-refresh = {
    enable = true;
    apiTokenFile = "/run/secrets/jellyfin/epg-api-token";
  };

  hq.audio.streamTo = "";

  # Scraped by the grafana microvm on mireo (10.8.0.2)
  services.prometheus.exporters.node.enable = true;

  programs.noisetorch.enable = true;
}
