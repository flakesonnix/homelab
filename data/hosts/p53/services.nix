{
  lib,
  pkgs,
  ...
}: {
  # --- sops-nix secrets (Key via `nix run .#setup-sops` nach /etc/sops/age/keys.txt) ---
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/p53/secrets.yaml;
  };

  # Täglicher XMLTV-Guide für die Jellyfin-MicroVM (iptv-org/epg, host-seitig
  # gebaut, per SSH geschoben). API-Token liegt in hosts/p53/secrets.yaml
  # (jellyfin/epg-api-token), Key auf der VM als `epg-setup` angelegt.
  sops.secrets."jellyfin/epg-api-token" = {};
  services.epg-refresh = {
    enable = true;
    apiTokenFile = "/run/secrets/jellyfin/epg-api-token";
  };

  hq.audio.streamTo = "";

  # Scraped by the grafana microvm on mireo (10.8.0.2)
  services.prometheus.exporters.node.enable = true;

  services.ollama = {
    enable = true;
    package = (pkgs.ollama-cuda.override {cudaArches = ["sm_75"];}).overrideAttrs (old: {
      # Nixpkgs' Ollama 0.32.3 strips the CUDA major from the merged store path.
      env = old.env // {CUDA_PATH = "${old.env.CUDA_PATH}-${lib.versions.major pkgs.cudaPackages.cuda_cudart.version}";};
      # Its nested CMake bypasses the setup hook's array flags and needs one root.
      preBuild =
        ''
          export CUDAToolkit_ROOT="$CUDA_PATH"
        ''
        + old.preBuild;
    });
  };

  programs.noisetorch.enable = true;
}
