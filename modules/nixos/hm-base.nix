{
  lib,
  stylix,
  nix-flatpak,
  frameworkLib,
  ...
}: {
  home-manager.backupFileExtension = "hm-backup";

  home-manager.users.lucy = {
    imports = [
      ../../home/lucy
      stylix.homeModules.stylix
      nix-flatpak.homeManagerModules.nix-flatpak
    ];
    nixpkgs.config.allowUnfree = true;
  };

  home-manager.extraSpecialArgs = {
    inherit frameworkLib;
  };
}
