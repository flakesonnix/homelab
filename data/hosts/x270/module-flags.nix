{
  lucy.gnome.enable = false;
  lucy.gnomeExtensions.enable = false;

  # KDE Plasma 6 parallel zu Niri (Session per greetd-tuigreet wählbar).
  lucy.plasma.enable = true;

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

  # Desktop fonts and common UI tools.
  lucy.fonts.inter = true;
  lucy.pwvucontrol = true;
}
