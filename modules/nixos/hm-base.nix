{ lib, pkgs, stylix, nix-flatpak, nix-index-database, ... }:

{
  home-manager.backupFileExtension = "backup";

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  home-manager.users.lucy = {
    imports = [
      ../../home/lucy
      stylix.homeModules.stylix
      nix-flatpak.homeManagerModules.nix-flatpak
      nix-index-database.homeModules.default
    ];
    nixpkgs.config.allowUnfree = true;
  };
}
