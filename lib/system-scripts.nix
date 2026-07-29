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

}
