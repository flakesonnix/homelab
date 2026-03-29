{
  description = "NixOS dotfiles for lucy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      lib = import ./lib;
    in
    {
      lib = import ./lib;

      nixosConfigurations.p50 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit lib; };
        modules =
          [
            ./hosts/p50
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.lucy = import ./home/lucy;
            }
          ];
      };

      homeConfigurations."lucy@p50" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ import ./home/lucy ];
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          nixpkgs-fmt
          nil
          git
        ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
