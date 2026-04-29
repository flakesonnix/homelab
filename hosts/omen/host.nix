{
  lib,
  pkgs,
  wrappers,
  ...
}: let
  projectLib = import ../../lib;
  enabledLucyPackages = [
    "firefox"
    "discord"
    "clion"
    "ollama"
    "lmstudio"
    "swaybg"
    "devBase"
    "pwvucontrol"
    "scrcpy"
    "nload"
    "iotop"
    "iftop"
  ];

  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in {
  networking.hostName = "omen";
  networking.networkmanager.enable = true;

  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["r8169"];
  boot.kernelParams = [
    "tpm.disable=1"
    "nvme_core.default_ps_max_latency_us=0"
    "console=tty1"
  ];

  nix.settings.require-sigs = false;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  security.run0-sudo-shim.enable = true;
  hardware.nvidia.powerManagement.enable = lib.mkForce false;

  lucy = lib.mkMerge (
    [
      {
        base.enable = true;
        base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
        base.sshKeyComment = "lucy@p50";
        nvidia.enable = true;
        gnome.enable = false;
        gnomeExtensions.enable = false;
        gaming.enable = true;
        fonts.inter = true;
        niri.enable = true;
        waybar.installFonts = true;
        basePackages = with pkgs; [
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
          kdePackages.kdenlive
          ani-cli
          scdl
        ];
      }
    ]
    ++ projectLib.enableAttrs lib enabledLucyPackages
  );

  environment.systemPackages = [hyfetch-wrapped];
  fonts.packages = with pkgs; [hack-font];

  services.openssh.settings.PermitRootLogin = "prohibit-password";
  system.stateVersion = "25.11";
}
