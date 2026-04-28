_: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "ollama.cachix.org-1:5Sgl02t2AMtL/y8rfl7GeG5p+rM6UXCdN2nJZh3BDk="
        "cache.nixos-cuda.org-1:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-gaming.cachix.org"
        "https://ollama.cachix.org"
        "https://cache.nixos-cuda.org"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;
}
