{
  description = "NixOS dotfiles for lucy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
    };

  };

  outputs = inputs@{ self, nixpkgs, deploy-rs, home-manager, stylix, wrappers, nix-flatpak, nixos-hardware, sops-nix, flake-parts, nix-index-database, ... }:
    let
      p50-config = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit wrappers; };
        modules = [
          ./nix-settings.nix
          ./profiles/desktop.nix
          ./hosts/p50
          nixos-hardware.nixosModules.lenovo-thinkpad-p50
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
            home-manager.users.lucy = {
              imports = [
                ./home/lucy
                stylix.homeModules.stylix
                nix-flatpak.homeManagerModules.nix-flatpak
                nix-index-database.homeModules.default
              ];
              nixpkgs.config.allowUnfree = true;
            };
          }
        ];
      };

      desktop-config = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit wrappers; };
        modules = [
          ./nix-settings.nix
          ./profiles/desktop.nix
          ./hosts/desktop
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
            home-manager.users.lucy = {
              imports = [
                ./home/lucy
                stylix.homeModules.stylix
                nix-flatpak.homeManagerModules.nix-flatpak
                nix-index-database.homeModules.default
              ];
              nixpkgs.config.allowUnfree = true;
            };
          }
        ];
      };

      omen-config = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit wrappers; };
        modules = [
          ./nix-settings.nix
          ./profiles/desktop.nix
          ./hosts/omen
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
            home-manager.users.lucy = {
              imports = [
                ./home/lucy
                stylix.homeModules.stylix
                nix-flatpak.homeManagerModules.nix-flatpak
                nix-index-database.homeModules.default
              ];
              nixpkgs.config.allowUnfree = true;
            };
          }
        ];
      };

      deploy-lib = deploy-rs.lib.x86_64-linux;
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        systems = [ "x86_64-linux" ];

        perSystem = { config, pkgs, ... }: {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nixpkgs-fmt
              nil
              git
              pandoc
              texliveMinimal
              librsvg
              deploy-rs.packages.x86_64-linux.default
            ];
          };

          formatter = pkgs.nixpkgs-fmt;
        };
      }
      //
      {
        flake = {
          lib = import ./lib;

          nixosConfigurations = {
            p50 = p50-config;
            desktop = desktop-config;
            omen = omen-config;
          };

          homeConfigurations."lucy@p50" = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
            modules = [ import ./home/lucy stylix.homeModules.stylix ];
          };

          packages.x86_64-linux = { };

          deploy.nodes = {
            p50 = {
              hostname = "192.168.178.31";
              profiles.system = {
                path = deploy-lib.activate.nixos p50-config;
                user = "root";
              };
              remoteBuild = true;
              ssh_user = "root";
            };
            desktop = {
              hostname = "192.168.178.2";
              profiles.system = {
                path = deploy-lib.activate.nixos desktop-config;
                user = "root";
              };
              remoteBuild = true;
              ssh_user = "root";
            };
            omen = {
              hostname = "192.168.178.4";
              profiles.system = {
                path = deploy-lib.activate.nixos omen-config;
                user = "root";
              };
              remoteBuild = true;
              ssh_user = "root";
              sshOpts = [ "-t" ];
            };
          };
        };
      }
    );
}
