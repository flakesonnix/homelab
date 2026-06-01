{pkgs, ...}: let
  audioOutputApp = (import ../../../lib/audio-scripts.nix pkgs).mkAudioSwitcher {};
in {
  # --- sops-nix secrets (uncomment after running `nix run .#setup-sops`) ---
  # lucy.secrets = {
  #   enable = true;
  #   sopsFile = ../../../hosts/omen/secrets.yaml;
  # };

  lucy.hostPackages = [audioOutputApp];

  services.asteriskLocal = {
    enable = false;
    # secrets.enable = true;  # Enable with sops-nix templated config

    # Keep empty in repo; set locally (ideally via sops-nix template).
    openFirewall = true;
    phones = {};
    extraExtensions = "";
  };

  # The receiver is currently reachable on omen via the `p50` host mapping.
  hq.audio.streamTo = "p50";

  programs.noisetorch.enable = true;

  # nix-serve-ng → LAN binary cache for p50/mireo
  # Manual service (nixpkgs nix-serve module stale, crashes as nix-serve user)
  systemd.services.nix-serve = {
    description = "nix-serve-ng binary cache server";
    after = ["network.target" "nix-daemon.service"];
    wantedBy = ["multi-user.target"];
    environment.NIX_REMOTE = "daemon";
    serviceConfig = {
      ExecStart = "${pkgs.nix-serve-ng}/bin/nix-serve --listen 0.0.0.0:5000";
      User = "root";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  networking.firewall.allowedTCPPorts = [5000];
}
