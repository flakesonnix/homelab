{
  description = "NixOS dotfiles for lucy";

  nixConfig = {
    accept-flake-config = true;
    extra-substituters = ["https://nix-gaming.cachix.org"];
    extra-trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
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

    flake-root = {
      url = "github:srid/flake-root";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    nixGaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    stylix,
    wrappers,
    nix-flatpak,
    sops-nix,
    flake-parts,
    nix-index-database,
    lanzaboote,
    comfyui-nix,
    run0-sudo-shim,
    microvm,
    nixos-hardware,
    nixGaming,
    nur,
    deploy-rs,
    ...
  }: let
    projectLib = import ./lib;
    omen-config = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database nixos-hardware nixGaming;
        frameworkLib = projectLib;
      };
      modules = [
        ./nix-settings.nix
        ./profiles/desktop.nix
        ./hosts/omen
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        lanzaboote.nixosModules.lanzaboote
        nur.modules.nixos.default
        ({lib, ...}: {
          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
          };
        })
        ./modules/nixos/hm-base.nix
        run0-sudo-shim.nixosModules.default
      ];
    };
    p50-config = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database nixos-hardware nixGaming;
        frameworkLib = projectLib;
      };
      modules = [
        ./nix-settings.nix
        ./profiles/desktop.nix
        ./hosts/p50
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        nur.modules.nixos.default
        ./modules/nixos/hm-base.nix
        run0-sudo-shim.nixosModules.default
        ./modules/nixos/pipebert.nix
      ];
    };
    mireo-config = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database nixos-hardware nixGaming;
        frameworkLib = projectLib;
      };
      modules = [
        ./nix-settings.nix
        ./profiles/base.nix
        microvm.nixosModules.host
        ./hosts/mireo
        ./hosts/mireo/grafana-microvm.nix
        sops-nix.nixosModules.sops
        nur.modules.nixos.default
        run0-sudo-shim.nixosModules.default
      ];
    };
    x61-config = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/x61
      ];
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} (
      {
        imports = [
          inputs.flake-root.flakeModule
          inputs.devshell.flakeModule
        ];
        systems = ["x86_64-linux"];

        perSystem = {
          system,
          pkgs,
          ...
        }: let
          rebuildApp = pkgs.writeShellApplication {
            name = "rebuild";
            runtimeInputs = [pkgs.nh];
            text = "nh os switch";
          };
          deployApp = host: pkgs.writeShellApplication {
            name = "deploy-${host}";
            runtimeInputs = [deploy-rs.packages.${system}.default];
            text = ''
              deploy .#${host}
            '';
          };
          checkApp = pkgs.writeShellApplication {
            name = "check";
            text = "nix flake check";
          };
          updateApp = pkgs.writeShellApplication {
            name = "update";
            text = "nix flake update";
          };
        in
          {
            formatter = pkgs.alejandra;

            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                alejandra
                python3
                statix
                nix-tree
              ];
            };

            packages = {
              "geforce-now-web" = pkgs.callPackage ./pkgs/by-name/ge/geforce_now {};
            };

            apps = {
              rebuild = {
                type = "app";
                program = "${rebuildApp}/bin/rebuild";
                meta.description = "Rebuild the omen host via nh";
              };
              check = {
                type = "app";
                program = "${checkApp}/bin/check";
                meta.description = "Run nix flake check";
              };
              update = {
                type = "app";
                program = "${updateApp}/bin/update";
                meta.description = "Update flake inputs";
              };
              deploy-omen = {
                type = "app";
                program = "${deployApp "omen"}/bin/deploy-omen";
                meta.description = "Deploy omen via deploy-rs (localhost)";
              };
              deploy-p50 = {
                type = "app";
                program = "${deployApp "p50"}/bin/deploy-p50";
                meta.description = "Deploy p50 via deploy-rs to 10.8.0.122";
              };
              deploy-mireo = {
                type = "app";
                program = "${deployApp "mireo"}/bin/deploy-mireo";
                meta.description = "Deploy mireo via deploy-rs to 192.168.178.25";
              };
              deploy-x61 = {
                type = "app";
                program = "${deployApp "x61"}/bin/deploy-x61";
                meta.description = "Deploy x61 via deploy-rs to 10.8.0.163";
              };
            };
          }
          // {
            checks =
              (import ./lib/flake/checks.nix {
                inherit self pkgs omen-config;
              }).checks
              // (import ./tests/checks.nix {
                inherit self pkgs omen-config p50-config mireo-config x61-config;
              }).checks
              // deploy-rs.lib.${system}.deployChecks self.deploy;
          };
      }
      // {
        flake = {
          lib = projectLib;

          nixosModules = {
            pipebert = import ./modules/nixos/pipebert.nix;
            nixos = import ./modules/nixos/default.nix;
            home = import ./modules/home/default.nix;
          };

          nixosConfigurations = {
            omen = omen-config;
            p50 = p50-config;
            mireo = mireo-config;
            x61 = x61-config;
          };

          deploy.nodes = let
            # nixos-rebuild-ng reexec step runs `nix-build '<nixpkgs/nixos>'` which
            # needs nixos-config in NIX_PATH. Flake-only systems don't set it.
            # Wrap switch-to-configuration with a stub nixos-config until
            # nix-settings.nix's environment.etc entry propagates via a reboot.
            activateNixosWithNixPath = nixosConfig: let
              stub = nixpkgs.legacyPackages.x86_64-linux.writeText "nixos-config.nix" "{ ... }: { }";
              nixPathEnv = "NIX_PATH=nixpkgs=flake:nixpkgs:nixos-config=${stub}";
            in
              (deploy-rs.lib.x86_64-linux.activate.custom // {
                dryActivate = "${nixPathEnv} $PROFILE/bin/switch-to-configuration dry-activate";
                boot = "${nixPathEnv} $PROFILE/bin/switch-to-configuration boot";
              })
              nixosConfig.config.system.build.toplevel
              "${nixPathEnv} $PROFILE/bin/switch-to-configuration switch";
          in {
            omen = {
              hostname = "localhost";
              sshUser = "root";
              profiles.system = {
                user = "root";
                path = activateNixosWithNixPath self.nixosConfigurations.omen;
              };
            };
            p50 = {
              hostname = "p50";
              sshUser = "root";
              profiles.system = {
                user = "root";
                path = activateNixosWithNixPath self.nixosConfigurations.p50;
              };
            };
            mireo = {
              hostname = "mireo";
              sshUser = "root";
              profiles.system = {
                user = "root";
                path = activateNixosWithNixPath self.nixosConfigurations.mireo;
              };
            };
            x61 = {
              hostname = "x61";
              sshUser = "root";
              profiles.system = {
                user = "root";
                path = activateNixosWithNixPath self.nixosConfigurations.x61;
              };
            };
          };
        };
      }
    );
}
