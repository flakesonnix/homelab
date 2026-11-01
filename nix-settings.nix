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
      # 0.8.3 stalls Electron screen sharing on PipeWire buffer starvation.
      # The upstream retry fix is included in 0.8.4; keep later versions intact.
      xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ prev.lib.optional (old.version == "0.8.3") (final.fetchpatch {
            name = "xdg-desktop-portal-wlr-buffer-starvation.patch";
            url = "https://github.com/emersion/xdg-desktop-portal-wlr/commit/8309000572212af2cd2705955d04c79db475a29a.patch";
            hash = "sha256-X0wlT5zgI6f6OPWRZjab4Yp/41Q2BqrJSxW0vYlCH4o=";
          });
      });

      qemu_full = prev.qemu_full.override {
        cephSupport = false;
      };
    })
  ];
}
