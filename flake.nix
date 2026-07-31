{
  description = "NixOS dotfiles for lucy";

  nixConfig = {
    accept-flake-config = true;
    extra-substituters = ["https://nix-gaming.cachix.org"];
    extra-trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
    warn-dirty = false;
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
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    run0-sudo-shim = {
      url = "github:lordgrimmauld/run0-sudo-shim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    framework = {
      url = "github:flakesonnix/rivotril";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yammat = {
      url = "git+https://gitea.c3d2.de/c3d2/yammat?ref=master";
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

    nix-topology = {
      url = "github:oddlama/nix-topology";
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
    lanzaboote,
    run0-sudo-shim,
    microvm,
    nixos-hardware,
    nixGaming,
    nur,
    framework,
    yammat,
    deploy-rs,
    nix-topology,
    ...
  }: let
    pkgsForPatch = import nixpkgs {system = "x86_64-linux";};
    patchedNixTopologySrc = pkgsForPatch.applyPatches {
      name = "nix-topology-patched";
      src = inputs.nix-topology;
      patches = [./patches/nix-topology-spacing.patch];
    };
    mkHost = {
      modules,
      specialArgs ? {},
    }:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit modules specialArgs;
      };

    omenSpecialArgs = {
      inherit wrappers stylix nix-flatpak nixos-hardware nixGaming;
      frameworkLib = framework.lib;
    };

    desktopSpecialArgs = {
      inherit wrappers stylix nix-flatpak nixos-hardware;
      frameworkLib = framework.lib;
    };

    serverSpecialArgs = {
      inherit wrappers;
      frameworkLib = framework.lib;
    };

    mireoSpecialArgs = {
      inherit wrappers yammat nixpkgs;
      frameworkLib = framework.lib;
    };

    omen-config = mkHost {
      specialArgs = omenSpecialArgs;
      modules = [
        ./nix-settings.nix
        ./profiles/desktop.nix
        ./hosts/omen
        ./modules/nixos/asterisk.nix
        ./modules/nixos/audio-stream.nix
        ./modules/nixos/fonts.nix
        ./modules/nixos/gaming.nix
        ./modules/nixos/gnome.nix
        ./modules/nixos/gnome-extensions.nix
        ./modules/nixos/niri.nix
        ./modules/nixos/nvidia.nix
        ./modules/nixos/nvidia-resume.nix
        ./modules/nixos/serial-getty.nix
        ./modules/nixos/sops.nix
        ./modules/nixos/waybar.nix
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
        ./modules/nixos/deskflow.nix
        ./modules/nixos/waydroid.nix
        run0-sudo-shim.nixosModules.default
      ];
    };
    mireo-config = mkHost {
      specialArgs = mireoSpecialArgs;
      modules = [
        ./nix-settings.nix
        ./profiles/base.nix
        microvm.nixosModules.host
        ./hosts/mireo
        ./hosts/mireo/grafana-microvm.nix
        nur.modules.nixos.default
        run0-sudo-shim.nixosModules.default
      ];
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} (
      {
        imports = [(import "${patchedNixTopologySrc}/flake-module.nix")];
        systems = ["x86_64-linux"];

        perSystem = {
          system,
          pkgs,
          ...
        }: let
          dotfilesLib = import ./lib/default.nix pkgs;
          # Framework template checks that target components this repo
          # doesn't ship are excluded from the aggregate CI bundle.
          frameworkChecks =
            builtins.removeAttrs
            (
              import "${framework.outPath}/lib/flake/checks.nix" {
                inherit self pkgs framework omen-config;
              }
            ).checks ["webui-unit"];
          deployChecks = deploy-rs.lib.${system}.deployChecks self.deploy;
          dotfilesChecks = import ./tests/default.nix {
            inherit pkgs microvm;
            lib = pkgs.lib;
            inherit self;
          };
          fullCiChecks = dotfilesLib.ciScripts.mkCiCheckBundle {
            checks =
              frameworkChecks
              // deployChecks
              // dotfilesChecks;
          };
          rebuildApp = pkgs.writeShellApplication {
            name = "rebuild";
            runtimeInputs = [pkgs.nh];
            text = "nh os switch";
          };
          setupSopsApp = dotfilesLib.mkSetupSops "setup-sops";
          deployApp = host:
            pkgs.writeShellApplication {
              name = "deploy-${host}";
              runtimeInputs = [deploy-rs.packages.${system}.default];
              text = ''
                deploy .#${host}
              '';
            };
          checkApp = dotfilesLib.ciScripts.mkCheckApp {
            name = "check";
            evalTargets = [
              ".#formatter.x86_64-linux.drvPath"
              ".#devShells.x86_64-linux.default.drvPath"
              ".#apps.x86_64-linux.rebuild.type"
            ];
            buildTargets = [
              ".#full-ci-checks"
              ".#checks.x86_64-linux.dotfiles-tests"
            ];
          };
          checkLightApp = dotfilesLib.ciScripts.mkCheckApp {
            name = "check-light";
            evalTargets = [
              ".#formatter.x86_64-linux.drvPath"
              ".#devShells.x86_64-linux.default.drvPath"
              ".#apps.x86_64-linux.rebuild.type"
            ];
          };
          checkFullApp = dotfilesLib.ciScripts.mkCheckApp {
            name = "check-full";
            buildTargets = [".#full-ci-checks"];
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
                statix
                nix-tree
              ];
            };

            topology.modules = [./topology.nix];
            topology.nixosConfigurations =
              builtins.mapAttrs (
                _: cfg:
                  cfg.extendModules {
                    modules = [
                      nix-topology.nixosModules.default
                      ./modules/nixos/topology.nix
                    ];
                  }
              )
              self.nixosConfigurations;

            packages = {
              full-ci-checks = fullCiChecks;
              topology = pkgs.runCommand "topology-fixed" {} ''
                cp -r ${self.topology.x86_64-linux.config.output} $out
                chmod +w $out $out/network.svg
                ${dotfilesLib.topologyScripts.fixNetworkSvg {}}/bin/fix-network-svg $out/network.svg
              '';
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
              check-light = {
                type = "app";
                program = "${checkLightApp}/bin/check-light";
                meta.description = "Run light flake surface checks";
              };
              check-full = {
                type = "app";
                program = "${checkFullApp}/bin/check-full";
                meta.description = "Run full CI check builds";
              };
              update = {
                type = "app";
                program = "${updateApp}/bin/update";
                meta.description = "Update flake inputs";
              };
              deploy-omen = {
                type = "app";
                program = "${rebuildApp}/bin/rebuild";
                meta.description = "Rebuild omen locally via nh";
              };
              deploy-mireo = {
                type = "app";
                program = "${deployApp "mireo"}/bin/deploy-mireo";
                meta.description = "Deploy mireo via deploy-rs to 192.168.178.25";
              };
              setup-sops = {
                type = "app";
                program = "${setupSopsApp}/bin/setup-sops";
                meta.description = "Generate sops-nix age key pair";
              };
            };
          }
          // {
            checks = dotfilesChecks;
          };
      }
      // {
        flake = {
          inherit (framework) lib;

          nixosModules = {
            nixos = import ./modules/nixos/default.nix;
            home = import ./modules/home/default.nix;
          };

          nixosConfigurations = {
            omen = omen-config;
            mireo = mireo-config;
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
              (deploy-rs.lib.x86_64-linux.activate.custom
                // {
                  dryActivate = "${nixPathEnv} $PROFILE/bin/switch-to-configuration dry-activate";
                  boot = "${nixPathEnv} $PROFILE/bin/switch-to-configuration boot";
                })
              nixosConfig.config.system.build.toplevel
              "${nixPathEnv} $PROFILE/bin/switch-to-configuration switch";
          in {
            mireo = {
              hostname = "10.8.0.1";
              sshUser = "root";
              profiles.system = {
                user = "root";
                path = activateNixosWithNixPath self.nixosConfigurations.mireo;
              };
            };
          };
        };
      }
    );
}
