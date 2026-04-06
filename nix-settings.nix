{ lib, config, ... }:

{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWyzPY0oqSzmC7kiNqdCXUcrKHC6A="
      ];
      substituters = [
        "https://cache.nixos.org"
      ];
    };
  };
}
