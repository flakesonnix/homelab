{ lib, config, ... }:

{
nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWyzPY0oqSzmC7kiNqdCXUcrKHC6A="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "ollama.cachix.org-1:5Sgl02t2AMtL/y8rfl7GeG5p+rM6UXCdN2nJZh3BDk="
        "cache.nixos-cuda.org-1:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
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
