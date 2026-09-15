# Uptime Kuma status monitoring (microVM on br0, behind Caddy on mireo).
# Uses the official nixpkgs module (services.uptime-kuma) with defaults
# (SQLite, /var/lib/uptime-kuma, :3001) — only HOST is overridden because
# the reverse proxy runs OUTSIDE this VM. No TLS inside the VM.
# Static user (not DynamicUser): DynamicUser + StateDirectory fails on a
# mounted volume (exit 238, "Device or resource busy"), so the module's
# DynamicUser is forced off and the volume is chowned to the static user.
# First start needs a manual admin account via the web UI (one-time).
{lib, ...}: {
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
          user = "uptime-kuma";
          group = "uptime-kuma";
        }
      ];
      config = {
        users.users.uptime-kuma = {
          isSystemUser = true;
          group = "uptime-kuma";
        };
        users.groups.uptime-kuma = {};
        systemd.services.uptime-kuma.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "uptime-kuma";
        };
        services.uptime-kuma = {
          enable = true;
          settings.HOST = "0.0.0.0";
        };
      };
    })
  ];
}
