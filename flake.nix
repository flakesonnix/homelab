{
  description = "NixOS dotfiles for lucy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrappers = {
      url = "github:lassulus/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, stylix, wrappers, nix-flatpak, ... }:
    let
      myLib = import ./lib;
    in
    {
      lib = myLib;

      nixosConfigurations.p50 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit wrappers; };
        modules = [
          ./nix-settings.nix
          ./profiles/desktop.nix
          ./hosts/p50
          home-manager.nixosModules.home-manager
          {
            p50.nixSettings = true;
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
            home-manager.users.lucy = {
              imports = [ 
                ./home/lucy 
                stylix.homeModules.stylix
                nix-flatpak.homeManagerModules.nix-flatpak
              ];
            };
          }
        ];
      };

      homeConfigurations."lucy@p50" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ import ./home/lucy stylix.homeModules.stylix ];
      };

      packages.x86_64-linux = { };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          nixpkgs-fmt
          nil
          git
          pandoc
          texliveMinimal
          librsvg
        ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
