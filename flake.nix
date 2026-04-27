{
  description = "NixOS dotfiles for lucy";

  nixConfig = {
    accept-flake-config = true;
    warn-dirty = false;
    warnImplicit = false;
  };

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

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    run0-sudo-shim = {
      url = "github:lordgrimmauld/run0-sudo-shim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ self, nixpkgs, home-manager, stylix, wrappers, nix-flatpak, sops-nix, flake-parts, nix-index-database, lanzaboote, comfyui-nix, treefmt-nix, pre-commit-hooks, run0-sudo-shim, ... }:
    let

      omen-config = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database; };
        modules = [
          ./nix-settings.nix
          ./profiles/desktop.nix
          ./hosts/omen
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
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
          run0-sudo-shim.nixosModules.default
        ];
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        imports = [
          inputs.devshell.flakeModule
        ];
        systems = [ "x86_64-linux" ];

        perSystem = { system, pkgs, ... }: {
          devshells.default = {
            name = "dotfiles";
            packages = with pkgs; [
              nixpkgs-fmt
              nil
              git
              pandoc
              texliveMinimal
              librsvg
              statix
              deadnix
              nix-direnv
            ];
            commands = [
              { name = "rebuild"; command = "nh os switch"; help = "Rebuild omen host"; }
              { name = "update"; command = "nix flake update"; help = "Update flake inputs"; }
              { name = "fmt"; command = "nix fmt"; help = "Format the repository"; }
              { name = "check"; command = "nix flake check"; help = "Check the flake"; }
            ];
          };

          formatter = (treefmt-nix.lib.evalModule pkgs ./treefmt.nix).config.build.wrapper;

          checks = {
            formatting = (treefmt-nix.lib.evalModule pkgs ./treefmt.nix).config.build.check self;
            pre-commit = pre-commit-hooks.lib.${system}.run {
              src = self;
              hooks = {
                nixpkgs-fmt.enable = true;
                statix.enable = true;
                deadnix.enable = true;
              };
            };
          };
        };
      }
      //
      {
        flake = {
          lib = import ./lib;

          nixosConfigurations = {
            omen = omen-config;
          };
        };
      }
    );
}
