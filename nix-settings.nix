{ lib, config, ... }:

{
nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "ollama.cachix.org-1:+8gHyhs2wZvI/0A7kujPWiPM4LlgFjEKhcOvl5n9jss="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://ollama.cachix.org"
        "https://cache.nixos-cuda.org"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;
}
