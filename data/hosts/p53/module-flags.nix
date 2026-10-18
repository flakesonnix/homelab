{
  lucy.gnome.enable = true;
  lucy.gnomeExtensions.enable = true;

  # GNOME and SwayFX share GDM; neither Niri nor Plasma replaces the greeter.
  programs.sway.enable = true;
  lucy.plasma.enable = false;

  # EWM (Emacs Wayland Manager) as an additional GDM session.
  lucy.ewm.enable = true;

  # Sunshine Game-Streaming (Moonlight), Firewall + Autostart an.
  lucy.sunshine.enable = true;

  # Quadro M1000M (Maxwell): Legacy-580-Treiber + PRIME-Offload.
  # Intel treibt das Display, Nvidia per `nvidia-offload` / NVENC (Sunshine).
  lucy.nvidia.enable = true;
  lucy.nvidia.legacy580 = true;
  lucy.nvidia.prime = true;
  lucy.nvidia.intelBusId = "PCI:0:2:0";
  lucy.nvidia.nvidiaBusId = "PCI:1:0:0";

  lucy.waydroid.enable = true;

  # Smartcard reader (PC/SC via pcscd; ccid plugin + udev rules included).
  services.pcscd.enable = true;

  # Fingerprint reader (Synaptics 06cb:00bd, libfprint prometheus driver).
  # Enables fprintd + PAM fprintAuth (sufficient) for sudo/su/polkit/login
  # and GDM's gdm-fingerprint stack automatically (password stays as
  # fallback). Enroll after rebuild via GNOME Settings → Users →
  # Fingerprint Login or `fprintd-enroll`. Note: LUKS unlock at boot and
  # GNOME keyring unlock still need the password.
  services.fprintd.enable = true;

  # Desktop fonts and common UI tools.
  lucy.fonts.inter = true;
  lucy.pwvucontrol = true;
}
