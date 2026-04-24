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

     lanzaboote = {
       url = "github:nix-community/lanzaboote/v1.0.0";
       inputs.nixpkgs.follows = "nixpkgs";
     };

     comfyui-nix = {
       url = "github:utensils/comfyui-nix";
       inputs.nixpkgs.follows = "nixpkgs";
     };

  };

   outputs = inputs@{ self, nixpkgs, nix-topology, deploy-rs, home-manager, stylix, wrappers, nix-flatpak, sops-nix, flake-parts, nix-index-database, lanzaboote, comfyui-nix, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nix-topology.overlays.default ];
      };

      omen-config = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database; };
          modules = [
            ./nix-settings.nix
            ./profiles/desktop.nix
            ./hosts/omen
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            nix-topology.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            ({ lib, pkgs, ... }: {
              boot.loader.systemd-boot.enable = lib.mkForce false;
              boot.lanzaboote = {
                enable = true;
                pkiBundle = "/var/lib/sbctl";
              };
              environment.systemPackages = [ pkgs.sbctl ];
            })
            ./modules/nixos/hm-base.nix
          ];
        };

      homelab-config = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database; };
          modules = [
            ./nix-settings.nix
            ./profiles/base.nix
            ./hosts/homelab
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            nix-topology.nixosModules.default
            ./modules/nixos/hm-base.nix
          ];
        };

      

      nixos-configs = {
        omen = omen-config;
        homelab = homelab-config;
      };

      deploy-lib = deploy-rs.lib.x86_64-linux;

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

          nixosConfigurations = nixos-configs;

          packages.x86_64-linux = {
            topology = topology.config.output;
          };

          deploy.nodes = {
            omen = {
              hostname = "192.168.178.4";
              profiles.system = {
                path = deploy-lib.activate.nixos omen-config;
                user = "root";
              };
              remoteBuild = false;
              ssh_user = "root";
              sshOpts = [ "-t" "-o" "StrictHostKeyChecking=no" ];
            };
            homelab = {
              hostname = "10.8.1";
              profiles.system = {
                path = deploy-lib.activate.nixos homelab-config;
                user = "root";
              };
              remoteBuild = false;
              ssh_user = "root";
              sshOpts = [ "-t" "-o" "StrictHostKeyChecking=no" "-o" "PreferredAuthentications=password,publickey" ];
            };
          };
        };
      }
    );
}
