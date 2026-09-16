{
  # --- sops-nix secrets (uncomment after running `nix run .#setup-sops`) ---
  # lucy.secrets = {
  #   enable = true;
  #   sopsFile = ../../../hosts/x270/secrets.yaml;
  # };

  hq.audio.streamTo = "";

  # Scraped by the grafana microvm on mireo (10.8.0.2)
  services.prometheus.exporters.node.enable = true;

  programs.noisetorch.enable = true;
}
