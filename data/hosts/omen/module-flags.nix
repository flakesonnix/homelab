{
  lucy.base.enable = true;
  # On this machine we run Niri on the iGPU; avoid failing boots when
  # NVIDIA kernel modules aren't present for the currently booted kernel.
  lucy.nvidia.enable = false;
  lucy.gnome.enable = false;
  lucy.gnomeExtensions.enable = false;

  # Desktop fonts and common UI tools.
  lucy.fonts.inter = true;
  lucy.pwvucontrol = true;
}
