_: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "ollama.cachix.org-1:+8gHyhs2wZvI/0A7kujPWiPM4LlgFjEKhcOvl5n9jss="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
      # No hard dependency on any single cache: cache.nixos.org is always first
      # and is the fallback; optional caches (nix-gaming, ollama, cuda) are
      # tried after. If a cache is unreachable (e.g. old http://omen:5000 which
      # was removed in 0397ed5), Nix will warn and fall back — it must not block
      # the build. Keep connect-timeout low so a dead cache fails fast.
      substituters = [
        "https://cache.nixos.org"
        "https://nix-gaming.cachix.org"
        "https://ollama.cachix.org"
        "https://cache.nixos-cuda.org"
      ];
      connect-timeout = 5;
      fallback = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      libdisplay-info = prev.libdisplay-info.overrideAttrs (finalAttrs: {
        version = "0.3.0";
        src = final.fetchFromGitLab {
          domain = "gitlab.freedesktop.org";
          owner = "emersion";
          repo = "libdisplay-info";
          rev = finalAttrs.version;
          sha256 = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
        };
      });
      niri = prev.niri.override {inherit (final) libdisplay-info;};

      qemu_full = prev.qemu_full.override {
        cephSupport = false;
      };
    })
  ];
}
