# Jellyfin media server (microVM on br0, behind Caddy on mireo).
# Uses the official nixpkgs module (services.jellyfin) with defaults
# (dataDir /var/lib/jellyfin, :8096, software transcoding). No TLS/state
# inside the VM. Media libraries (/data/…) can be added later via an
# extra read-only virtiofs share once the media directory exists.
{
  imports = [
    (import ./mk-microvm.nix {
      name = "jellyfin";
      ip = (import ./vm-ips.nix).jellyfin;
      mem = 2304; # NB: never exactly 2048 (QEMU hangs, microvm.nix#171)
      vcpu = 2;
      tcpPorts = [22 8096];
      volumes = [
        {
          image = "jellyfin-data.img";
          mountPoint = "/var/lib/jellyfin";
          size = 8192;
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
