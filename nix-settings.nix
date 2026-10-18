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

      # niri 26.04: libdisplay-info-sys 0.3.0 probes the C library with
      # `version = ">= 0.1.0, < 0.4.0"`, but this nixpkgs pin only ships
      # 0.4.0 — so niri gets a private 0.3.0 (hash matches upstream
      # libdisplay-info_0_3). Scoped to niri; the global libdisplay-info
      # stays at 0.4.0. Drop once the flake input provides
      # libdisplay-info_0_3 (then use `niri.override { inherit
      # libdisplay-info_0_3; }` or nothing — upstream niri already
      # defaults to _0_3 there).
      niri = prev.niri.override {
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
      };

      qemu_full = prev.qemu_full.override {
        cephSupport = false;
      };
    })
  ];
}
