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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, stylix, ... }:
    let
      myLib = import ./lib;
    in
    {
      lib = myLib;

      nixosConfigurations.p50 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nix-settings.nix
          home-manager.nixosModules.home-manager
          {
            p50.nixSettings = true;
            imports = [ ./hosts/p50 ];
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
            home-manager.users.lucy = {
              imports = [ ./home/lucy stylix.homeModules.stylix ];
            };
          }
        ];
      };

      homeConfigurations."lucy@p50" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ import ./home/lucy stylix.homeModules.stylix ];
      };

      packages.x86_64-linux =
        let
          docs = import ./docs { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
        in
        {
          docs = docs;
          docs-html = docs.out;
          docs-pdf = docs.out;
          docs-epub = docs.out;
        };

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
