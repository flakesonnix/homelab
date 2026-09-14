# Uptime Kuma status monitoring (microVM on br0, behind Caddy on mireo).
# Uses the official nixpkgs module (services.uptime-kuma) with defaults
# (SQLite, /var/lib/uptime-kuma, :3001) — only HOST is overridden because
# the reverse proxy runs OUTSIDE this VM. No TLS/state inside the VM.
# First start needs a manual admin account via the web UI (one-time).
{
  imports = [
    (import ./mk-microvm.nix {
      name = "uptime-kuma";
      ip = (import ./vm-ips.nix).uptime-kuma;
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 3001];
      volumes = [
        {
          image = "uptime-kuma-data.img";
          mountPoint = "/var/lib/uptime-kuma";
          size = 1024;
          # No user/group: the module runs DynamicUser + StateDirectory,
          # systemd owns the mount. SQLite DB persists in the image.
        }
      ];
      config = {
        services.uptime-kuma = {
          enable = true;
          settings.HOST = "0.0.0.0";
        };
      };
    })
  ];
}
