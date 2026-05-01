{
  # --- sops-nix secrets (uncomment after running ./setup-sops.sh) ---
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

  hq.audio.streamTo = "192.168.178.2";

  programs.noisetorch.enable = true;
}
