{ lib, config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/gnome-extensions.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/openclaude.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-42997d57-8a2a-443a-851b-79ae5ec6dd42".device = "/dev/disk/by-uuid/42997d57-8a2a-443a-851b-79ae5ec6dd42";

  networking.hostName = "omen";
  networking.staticIP = {
    enable = true;
    address = "192.168.178.4";
    prefixLength = 24;
    gateway = "192.168.178.1";
    interface = "enp60s0";
  };

  boot.initrd.network.enable = true;
  boot.initrd.network.udhcpc.enable = true;
  boot.initrd.network.ssh.port = 2224;
  boot.initrd.availableKernelModules = [ "r8169" ];

  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  lucy.nvidia.enable = true;
  lucy.gnome.enable = true;
  lucy.gnome.wayland = false;
  lucy.gnomeExtensions.enable = true;
  # lucy.openclaude.enable = true;  # disabled - build issues

  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = false;
  };

  services.thermald.enable = true;

  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  systemd.services.nvidia-resume = {
    description = lib.mkForce "Reinitialize NVIDIA driver after resume";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.mkForce [
        "/bin/sh" "-c" ''
          #!/bin/sh
          # Re-bind the NVIDIA driver if it failed to resume properly
          if [ -d /sys/bus/pci/drivers/nvidia ]; then
            for dev in /sys/bus/pci/drivers/nvidia/*; do
              if [ -e "$dev" ]; then
                vendor=$(cat "$dev/vendor" 2>/dev/null)
                if [ "$vendor" = "0x10de" ]; then
                  devname=$(basename "$dev")
                  echo "$devname" > /sys/bus/pci/drivers/nvidia/unbind 2>/dev/null
                  echo "$devname" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null
                fi
              fi
            done
          fi
          # Restart GDM if needed
          systemctl restart gdm.service 2>/dev/null || true
        ''
      ];
    };
  };

  lucy.basePackages = with pkgs; [
    deskflow
  ];

  lucy.hostPackages = with pkgs; [ ];

  system.stateVersion = "25.11";
}
