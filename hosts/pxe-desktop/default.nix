# NixOS mit GNOME-Desktop als PXE-Netboot-Image.
#
# Baut KEIN ISO, sondern die zwei Dateien, die iPXE per HTTP lädt:
#   - bzImage (Kernel)
#   - initrd   (enthält das squashfs mit der kompletten System-Closure)
# Dazu menu.ipxe (daneben): lokales Boot-Menü mit netboot.xyz-Fallback.
#
# Grundlage ist netboot-base (kein iso-image-Modul!): installation-cd-*
# Module ziehen iso-image.nix rein, das image.extension/system.build.image
# doppelt belegt und die Auswertung sprengt. Die Desktop-Bits unten sind
# deshalb aus installation-cd-graphical-{base,gnome} + calamares-Modul
# übernommen, ohne deren ISO-Kette.
#
# Bauen:  nix build .#pxe-desktop-boot   (→ ./result mit bzImage/initrd/*.ipxe)
# Sync:   Dateien nach mireo:/data/pxe kopieren (Caddy serviert /boot/*,
#         dnsmasq chainloadet http://10.8.0.1/boot/menu.ipxe). Siehe
#         data/hosts/mireo/settings.nix (dnsmasq + Caddy).
{
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    # Netboot-Fundament (netboot.nix + base/installation-device-Profile +
    # enableAllHardware): liefert system.build.{kernel,netbootRamdisk,...}.
    (modulesPath + "/installer/netboot/netboot-base.nix")
  ];

  networking.hostName = "pxe-desktop";
  system.stateVersion = "25.11";

  # --- Grafischer Installer (aus installation-cd-graphical-*) ---
  services.xserver.enable = true;
  powerManagement.enable = true;

  services.desktopManager.gnome = {
    favoriteAppsOverride = ''
      [org.gnome.shell]
      favorite-apps=[ 'firefox.desktop', 'nixos-manual.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop', 'gparted.desktop' ]
    '';
    enable = true;
  };
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };
  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };

  # Calamares-Installer (aus installation-cd-graphical-calamares.nix).
  security.polkit.enablePkexecWrapper = true;
  programs.partition-manager.enable = true;
  environment.systemPackages = with pkgs; [
    calamares-nixos
    (makeAutostartItem {
      name = "calamares";
      package = calamares-nixos;
    })
    calamares-nixos-extensions
    glibcLocales
  ];
  i18n.supportedLocales = ["all"];

  # Wheel darf alles (nur Installationsmedium, vgl. graphical-base).
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Gäste-Treiber + Installer-Werkzeuge (aus graphical-base).
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;
  virtualisation.vmware.guest.enable = pkgs.stdenv.hostPlatform.isx86;
  virtualisation.hypervGuest.enable =
    pkgs.stdenv.hostPlatform.isx86 || pkgs.stdenv.hostPlatform.isAarch64;
  services.xe-guest-utilities.enable = pkgs.stdenv.hostPlatform.isx86;
  virtualisation.virtualbox.guest.enable = false;
  boot.plymouth.enable = true;
  environment.defaultPackages = with pkgs; [
    gparted
    vim
    nano
    firefox
    mesa-demos
  ];

  # Schlankes Netboot-Profil wie netboot-minimal ist hier ABSICHTLICH
  # nicht aktiv: Firmware/Dokus bleiben drin (Installer auf echter HW).
  documentation.man.enable = lib.mkDefault true;
}
