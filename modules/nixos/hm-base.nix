{
  lib,
  stylix,
  nix-flatpak,
  nix-index-database,
  frameworkLib,
  ...
}: {
  home-manager.backupFileExtension = "hm-backup";

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = ["wheel" "networkmanager"];
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

  home-manager.extraSpecialArgs = {
    inherit frameworkLib;
  };
}
