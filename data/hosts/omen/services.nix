{
  # --- sops-nix secrets (uncomment after running `nix run .#setup-sops`) ---
  # lucy.secrets = {
  #   enable = true;
  #   sopsFile = ../../../hosts/omen/secrets.yaml;
  # };

  services.asteriskLocal = {
    enable = false;
    # secrets.enable = true;  # Enable with sops-nix templated config

    # Keep empty in repo; set locally (ideally via sops-nix template).
    openFirewall = true;
    phones = {};
    extraExtensions = "";
  };

  hq.audio.streamTo = "";

  # Scraped by the grafana microvm on mireo (10.8.0.2)
  services.prometheus.exporters.node.enable = true;

  programs.noisetorch.enable = true;
}
