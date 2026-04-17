{
  description = "NixOS dotfiles for lucy";

  nixConfig = {
    accept-flake-config = true;
    warn-dirty = false;
    warnImplicit = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    hyprnix = {
      url = "github:flakesonnix/hyprnix";
    };

  };

  outputs = inputs@{ self, nixpkgs, nix-topology, deploy-rs, home-manager, stylix, wrappers, nix-flatpak, sops-nix, flake-parts, nix-index-database, hyprnix, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nix-topology.overlays.default ];
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
            nix-topology.nixosModules.default
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
            nix-topology.nixosModules.default
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

      nixos-configs = {
        desktop = desktop-config;
        omen = omen-config;
      };

      topology = import nix-topology {
        inherit pkgs;
        modules = [
          { nixosConfigurations = nixos-configs; }
        ];
      };
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
            desktop = desktop-config;
            omen = omen-config;
          };

          packages.x86_64-linux = {
            topology = (import nix-topology {
              inherit pkgs;
              modules = [
                { nixosConfigurations = nixos-configs; }
              ];
            }).config.output;
          };

          deploy.nodes = {
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
              sshOpts = [ "-t" "-o" "StrictHostKeyChecking=no" ];
            };
          };
        };
      }
    );
}