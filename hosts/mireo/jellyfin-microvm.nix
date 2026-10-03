# Jellyfin media server (microVM on br0, behind Caddy on mireo).
# Uses the official nixpkgs module (services.jellyfin) with defaults
# (dataDir /var/lib/jellyfin, :8096, software transcoding). No TLS/state
# inside the VM. Media library /data/Jellyfin is shared read-only via
# virtiofs (auto-mounted at /media; files are world-readable, so the
# guest jellyfin user needs no idmap). Add /media as library in the
# Jellyfin UI once (runtime state, not declarative).
{
  imports = [
    (import ./mk-microvm.nix {
      name = "jellyfin";
      ip = (import ./vm-ips.nix).jellyfin;
      mem = 2304; # NB: never exactly 2048 (QEMU hangs, microvm.nix#171)
      vcpu = 2;
      tcpPorts = [22 8096];
      shares = [
        {
          tag = "jellyfin-media";
          source = "/data/Jellyfin";
          mountPoint = "/media";
          readOnly = true;
        }
      ];
      volumes = [
        {
          image = "jellyfin-data.img";
          mountPoint = "/var/lib/jellyfin";
          # 2026-10-03: vollgelaufen (8G, v.a. livetv-Aufnahmen) -> 16G.
          # Image auf mireo per qemu-img/resize2fs erweitert.
          size = 16384;
          user = "jellyfin";
          group = "jellyfin";
        }
        # Transcode/cache dir: Jellyfin ≥10.9 refuses to start with <2 GiB
        # free in cacheDir, and the VM rootfs only has ~1 GiB (seen
        # 2026-09-14: "insufficient free space", SIGABRT loop). 4 GiB
        # covers the check plus transcode headroom.
        {
          image = "jellyfin-cache.img";
          mountPoint = "/var/cache/jellyfin";
          size = 4096;
          user = "jellyfin";
          group = "jellyfin";
        }
      ];
      config = {
        services.jellyfin.enable = true;
      };
    })
  ];
}
