# Optional custom installer; the default mireo PXE path uses netboot.xyz.
# iPXE cannot load the large initrd in contiguous low memory. GRUB chainloads
# the kernel/initrd over HTTP and can place the initrd above 4 GiB.
{ pkgs, nixpkgs }:
let
  desktop = nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ ./. ];
  };
  cfg = desktop.config;
  grubConfig = pkgs.writeText "grub.cfg" ''
    serial --unit=0 --speed=115200
    terminal_input console serial
    terminal_output console serial
    set timeout=8
    set default=0
    menuentry "NixOS Xfce-Desktop (Installer)" {
      linux (http,10.8.0.1)/boot/bzImage init=${cfg.system.build.toplevel}/init initrd=initrd ${pkgs.lib.concatStringsSep " " cfg.boot.kernelParams} console=tty0 console=ttyS0
      initrd (http,10.8.0.1)/boot/initrd
    }
  '';
in
pkgs.runCommand "pxe-desktop-boot" { } ''
  mkdir -p $out/boot/grub
  cp ${cfg.system.build.kernel}/${cfg.system.boot.loader.kernelFile} $out/bzImage
  cp ${cfg.system.build.netbootRamdisk}/initrd $out/initrd
  cp ${cfg.system.build.netbootIpxeScript}/netboot.ipxe $out/netboot.ipxe
  cp ${./menu.ipxe} $out/menu.ipxe
  cp ${./slirp-boot.ipxe} $out/slirp-boot.ipxe
  cp ${pkgs.ipxe}/undionly.kpxe $out/undionly.kpxe
  cp ${pkgs.ipxe}/snp.efi $out/snp.efi
  cp ${grubConfig} $out/boot/grub/grub.cfg
  ${pkgs.grub2}/bin/grub-mkimage -O i386-pc-pxe -o $out/grub.pxe -p /boot/grub \
    pxe tftp http boot linux normal serial terminal reboot halt echo configfile search test true sleep
  ${pkgs.grub2_efi}/bin/grub-mkimage -O x86_64-efi -o $out/grubx64.efi -p /boot/grub \
    efinet tftp http boot linux normal serial terminal reboot halt echo configfile search test
''
