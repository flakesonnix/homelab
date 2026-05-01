{
  services.asteriskLocal = {
    enable = false;

    # Keep empty in repo; set locally (ideally via sops-nix template).
    openFirewall = true;
    phones = {};
    extraExtensions = "";
  };

  hq.audio.streamTo = "192.168.178.2";

  programs.noisetorch.enable = true;
}
