{ lib, config, pkgs, wrappers, ... }:

let
  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/network.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/gnome-extensions.nix
    ../../modules/nixos/packages.nix
    ../../modules/nixos/latex.nix
    ../../modules/nixos/openclaude.nix
    ../../modules/nixos/asterisk.nix
    ../../modules/nixos/audio-stream.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "omen";
  networking.networkmanager.enable = true;

  boot.initrd.availableKernelModules = [ "r8169" ];

  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@p50";

  lucy.nvidia.enable = true;
  lucy.gnome.enable = true;
  lucy.gnomeExtensions.enable = true;

  hardware.nvidia.powerManagement.enable = lib.mkForce false;

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
          systemctl restart gdm.service 2>/dev/null || true
        ''
      ];
    };
  };

  services.asteriskLocal = {
    enable = false;
    openFirewall = true;
    phones = {
      desk1 = { extension = "1001"; password = "secret123"; };
      desk2 = { extension = "1002"; password = "secret456"; };
    };
    extraExtensions = ''
      exten => 9000,1,Dial(PJSIP/desk1&PJSIP/desk2,20)
      same => n,Hangup()
    '';
  };

  hq.audio.streamTo = "192.168.178.2";

  programs.noisetorch.enable = true;

  lucy.basePackages = with pkgs; [
    alacritty
    zathura
    fzf
    bat
    vesktop
    vlc
    p7zip
    thunderbird
    deskflow
    keepassxc
    nodejs_22
    ausweisapp
  ];

  lucy.hostPackages = with pkgs; [
    ani-cli
  ];

  # services.ollama = {
  #   enable = true;
  #   package = pkgs.ollama-cuda;
  # };

  # nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    hyfetch-wrapped
  ];

  services.openssh.settings.PermitRootLogin = "prohibit-password";

  system.stateVersion = "25.11";
}