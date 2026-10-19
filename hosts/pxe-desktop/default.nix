# NixOS mit Xfce-Desktop als PXE-Netboot-Image (Installer + Calamares).
#
# Baut KEIN ISO, sondern die zwei Dateien, die iPXE per HTTP lädt:
#   - bzImage (Kernel)
#   - initrd   (enthält das squashfs mit der kompletten System-Closure)
# Dazu menu.ipxe (daneben): lokales Boot-Menü mit netboot.xyz-Fallback.
#
# WICHTIG: iPXE braucht die initrd als EINEN zusammenhängenden Block unter
# 4 GB (32-Bit-Bootprotokoll) + temporär eine zweite Kopie beim Laden.
# Eine GNOME-initrd (2,9 GB) scheitert daran mit 0x2a818006 — unabhängig
# vom Gesamt-RAM (verifiziert bis 12 GB). Darum bewusst schlank: Xfce
# statt GNOME, nur de+en-Locales, keine Docs. Ziel: initrd ~1 GB, bootet
# per iPXE ab ~4 GB Ziel-RAM.
#
# Grundlage ist netboot-base (kein iso-image-Modul!): installation-cd-*
# Module ziehen iso-image.nix rein, das image.extension/system.build.image
# doppelt belegt und die Auswertung sprengt.
#
# Bauen:  nix build .#pxe-desktop-boot   (→ ./result mit bzImage/initrd/*.ipxe)
# Sync:   Dateien nach mireo:/data/pxe kopieren (Caddy serviert /boot/*,
#         optional per iPXE chain http://10.8.0.1/boot/menu.ipxe starten).
#         Pixiecore startet standardmaessig netboot.xyz, nicht dieses Image.
{
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    # Netboot-Fundament (netboot.nix + base/installation-device-Profile +
    # enableAllHardware): liefert system.build.{kernel,netbootRamdisk,...}.
    # Firmware bleibt AN (WLAN auf echter HW), dafür Docs/Locales runter.
    (modulesPath + "/installer/netboot/netboot-base.nix")
  ];

  networking.hostName = "pxe-desktop";
  system.stateVersion = "25.11";

  # --- Fette, für einen Installer sinnlose Desktop-Defaults abdrehen ---
  # services.graphical-desktop schaltet bei xserver.enable mit ein:
  # Screenreader (zieht Stimmen- + ML-Kram mit), Audioserver (zieht über
  # ffmpeg-headless das komplette clang mit: ~0,9 GB) und CJK-Fonts.
  # Thumbnailer (xfce-modul) zieht über libgepub webkit rein.
  # Alles mkForce: die Module setzen plain true.
  services.speechd.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  fonts.enableDefaultPackages = lib.mkForce false;
  fonts.packages = with pkgs; [dejavu_fonts];
  services.tumbler.enable = lib.mkForce false;

  # --- Schlank-Diät (iPXE-Limit, s. Kopf) ---
  documentation.enable = lib.mkForce false;
  # Nur de+en statt aller Locales (calamares-Modul will "all").
  i18n.supportedLocales = lib.mkForce ["de_DE.UTF-8/UTF-8" "en_US.UTF-8/UTF-8"];

  # --- Grafischer Installer (Xfce + LightDM-Autologin + Calamares) ---
  services.xserver.enable = true;
  powerManagement.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };
  # Netzwerkmanagement per Applet (WLAN im Installer), nixos darf schalten.
  networking.networkmanager.enable = true;
  programs.nm-applet.enable = true;
  users.users.nixos.extraGroups = ["networkmanager"];
  # USB-Sticks/Datenträger im Dateimanager einhängen.
  services.gvfs.enable = true;

  # Calamares-Installer (+ Autostart, Partitionierung).
  security.polkit.enablePkexecWrapper = true;
  programs.partition-manager.enable = true;
  environment.systemPackages = with pkgs; [
    calamares-nixos
    (makeAutostartItem {
      name = "calamares";
      package = calamares-nixos;
    })
    calamares-nixos-extensions
  ];

  # Wheel darf alles (nur Installationsmedium).
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Gäste-Treiber für virtualisierte Ziele + Installer-Werkzeuge.
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;
  virtualisation.vmware.guest.enable = pkgs.stdenv.hostPlatform.isx86;
  virtualisation.hypervGuest.enable =
    pkgs.stdenv.hostPlatform.isx86 || pkgs.stdenv.hostPlatform.isAarch64;
  services.xe-guest-utilities.enable = pkgs.stdenv.hostPlatform.isx86;
  virtualisation.virtualbox.guest.enable = false;
  environment.defaultPackages = with pkgs; [
    gparted
    nano
    firefox
  ];

  # Keine Absturz-Dumps und kein vollaufendes Journal auf den TmpFS-Laufwerken
  # des Live-Systems (ENOSPC-Schutz, Diagnose 2026-10-10).
  systemd.coredump.enable = false;
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=100M
  '';
}
