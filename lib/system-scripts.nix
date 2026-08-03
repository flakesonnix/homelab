pkgs: {
  # Lazy-load NVIDIA kernel modules after graphical.target.
  # Skips if modules aren't built for the currently running kernel (safe after
  # nixos-rebuild switch without reboot).
  mkNvidiaLoader = pkgs.writeShellApplication {
    name = "nvidia-loader";
    runtimeInputs = [pkgs.kmod];
    text = ''
      if ! modinfo -k "$(uname -r)" nvidia >/dev/null 2>&1; then
        exit 0
      fi
      exec modprobe nvidia nvidia_modeset nvidia_uvm nvidia_drm
    '';
  };

  # NetworkManager dispatcher that mounts mireo's NFS /data only while the
  # server actually answers. With plain x-systemd.automount every access to
  # ~/data when the home network is gone triggers an NFS mount attempt that
  # blocks the calling process for timeo*retrans even with soft mounts.
  mkMireoDataDispatcher = pkgs.writeShellApplication {
    name = "mireo-data-dispatcher";
    runtimeInputs = [pkgs.netcat-gnu pkgs.util-linux];
    text = ''
      mnt=/mnt/mireo/data

      reachable() {
        nc -z -w1 10.8.0.1 2049 2>/dev/null
      }

      case "''${2:-}" in
        up | connectivity-change)
          if reachable; then
            if ! mountpoint -q "$mnt" 2>/dev/null; then
              mount "$mnt" 2>/dev/null || true
            fi
          else
            umount -l "$mnt" 2>/dev/null || true
          fi
          ;;
        down | pre-down)
          umount -l "$mnt" 2>/dev/null || true
          ;;
      esac

      exit 0
    '';
  };
}
