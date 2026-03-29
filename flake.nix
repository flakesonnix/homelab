{
  description = "NixOS dotfiles for lucy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      myLib = import ./lib;
    in
    {
      lib = myLib;

      nixosConfigurations.p50 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nix-settings.nix
          {
            p50.nixSettings = true;
            imports = [ ./hosts/p50 ];
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
          }
        ];
      };

      homeConfigurations."lucy@p50" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ import ./home/lucy ];
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
