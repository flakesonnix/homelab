{
  lucy.gnome.enable = false;
  lucy.gnomeExtensions.enable = false;

  lucy.waydroid.enable = true;

  # Smartcard reader (PC/SC via pcscd; ccid plugin + udev rules included).
  services.pcscd.enable = true;

  # Desktop fonts and common UI tools.
  lucy.fonts.inter = true;
  lucy.pwvucontrol = true;
}
