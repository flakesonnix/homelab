{ config, pkgs, lib, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "installer";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [ "kvm-intel" ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
    authorizedKeysFiles = [
      "/etc/ssh/authorized_keys.d/lucy"
    ];
  };

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    password = "nixos";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFTESTKEYFORTESTINGONLY"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    nix
    openssh
    age
    sops
  ];

  environment.etc."bootstrap.sh".text = ''
    #!/bin/bash
    set -e

    echo "Bootstrap script for dotfiles installation"
    echo "=========================================="
    
    # Clone the dotfiles repo
    echo "Cloning dotfiles repository..."
    git clone https://github.com/yourusername/dotfiles.git /etc/nixos
    
    # Run nixos-install
    echo "Running nixos-install..."
    nixos-install --flake /etc/nixos#p50
    
    echo "Installation complete!"
    echo ""
    echo "Post-install steps:"
    echo "1. Import your GPG private key"
    echo "2. Set up USB key file for GPG decryption"
    echo "3. Run 'home-manager switch --flake .#lucy@p50'"
  '';
  environment.etc."bootstrap.sh".mode = "755";

  system.stateVersion = "25.11";
}
