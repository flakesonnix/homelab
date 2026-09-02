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

  # Custom flake outputs (intentional, used by external tools):
  # - deploy (deploy-rs): flake.deploy.nodes for `deploy .#<host>`
  # - topology (nix-topology): flake.topology for `nix build .#topology`
  # - nixfleetArtifacts (nixfleet): flake.nixfleetArtifacts for manifest/ui generation
  # Warnings about "unknown flake output" for these are expected and can be ignored;
  # they are not standard outputs like `packages` or `checks` but are required by
  # their respective tools. See docs/architecture.md and flake.nix comments.
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
    yammat,
    deploy-rs,
    nix-topology,
    ...
  }: let
    pkgsForPatch = import nixpkgs {system = "x86_64-linux";};
    nixfleetPkgs = import ./nixfleet/default.nix {pkgs = pkgsForPatch;};
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

    frameworkLib = import ./lib/framework;

    x270SpecialArgs = {
      inherit wrappers stylix nix-flatpak nixos-hardware nixGaming frameworkLib;
    };

    serverSpecialArgs = {
      inherit wrappers frameworkLib;
    };

    mireoSpecialArgs = {
      inherit wrappers yammat nixpkgs frameworkLib;
    };

    x270-config = mkHost {
      specialArgs = x270SpecialArgs;
      modules = [
        ./nix-settings.nix
        ./profiles/desktop.nix
        ./hosts/x270
        ./modules/nixos/asterisk.nix
        ./modules/nixos/audio-stream.nix
        ./modules/nixos/fonts.nix
        ./modules/nixos/gaming.nix
        ./modules/nixos/gnome.nix
        ./modules/nixos/gnome-extensions.nix
        ./modules/nixos/niri.nix
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
        ./modules/nixos/nixfleet.nix
        run0-sudo-shim.nixosModules.default
        ({lib, ...}: {
          lucy.nixfleet.api.package = lib.mkDefault nixfleetPkgs.api;
          lucy.nixfleet.agent.package = lib.mkDefault nixfleetPkgs.agent;
        })
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
        ./modules/nixos/cups.nix
        ./modules/nixos/nixfleet.nix
        nur.modules.nixos.default
        run0-sudo-shim.nixosModules.default
        ({lib, ...}: {
          lucy.nixfleet.api.package = lib.mkDefault nixfleetPkgs.api;
          lucy.nixfleet.agent.package = lib.mkDefault nixfleetPkgs.agent;
        })
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
              import ./lib/framework/flake/checks.nix {
                inherit self pkgs x270-config;
              }
            ).checks ["webui-unit"];
          deployChecks = deploy-rs.lib.${system}.deployChecks self.deploy;
          dotfilesChecks = import ./tests/default.nix {
            inherit pkgs microvm self;
            inherit (pkgs) lib;
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

          # Curated, human-labeled command list used by the interactive
          # `menu` launcher. Single source of truth for what's discoverable.
          menuEntries = {
            rebuild = "Rebuild local x270 via nh";
            "deploy-x270" = "Deploy x270 via deploy-rs to localhost";
            "deploy-mireo" = "Deploy mireo via deploy-rs to 10.8.0.1";
            check = "Run nix flake check";
            "check-light" = "Fast eval-surface checks";
            "check-full" = "Full CI check builds";
            update = "Update flake inputs";
            "setup-sops" = "Generate sops-nix age key pair";
            topology = "Build network/host topology SVGs";
            nixfleet = "nixfleet CLI (status, health)";
          };
          menuApp = pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [pkgs.fzf];
            text = ''
              entries='${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (n: d: "${n}|${d}") menuEntries)}'
              choice=$(printf '%s\n' "$entries" | fzf --delimiter='|' --with-nth=2 --prompt='run> ')
              [ -z "$choice" ] && exit 0
              name=''${choice%%|*}
              exec nix run ".#$name"
            '';
          };

          nixfleetPkgs = import ./nixfleet/default.nix {inherit pkgs;};
        in
          {
            formatter = pkgs.alejandra;

            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                alejandra
                statix
                nix-tree
                go
                nodejs_22
                just
                fzf
              ];
              shellHook = ''
                echo "dotfiles devShell — run 'just' to list commands, or 'just menu' for an interactive launcher."
              '';
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
                ${dotfilesLib.topologyScripts.fixNetworkSvgApp {}}/bin/fix-network-svg $out/network.svg
              '';
              nixfleet-api = nixfleetPkgs.api;
              nixfleet-agent = nixfleetPkgs.agent;
              nixfleet = nixfleetPkgs.cli;
              nixfleet-web = nixfleetPkgs.web;
              nixfleet-manifest = pkgs.writeText "manifest.json" self.nixfleetArtifacts.manifestJson;
              nixfleet-ui = pkgs.writeText "ui.json" self.nixfleetArtifacts.uiJson;
            };

            apps = {
              rebuild = {
                type = "app";
                program = "${rebuildApp}/bin/rebuild";
                meta.description = "Rebuild the x270 host via nh";
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
              deploy-x270 = {
                type = "app";
                program = "${deployApp "x270"}/bin/deploy-x270";
                meta.description = "Deploy x270 via deploy-rs to localhost";
              };
              deploy-mireo = {
                type = "app";
                program = "${deployApp "mireo"}/bin/deploy-mireo";
                meta.description = "Deploy mireo via deploy-rs to 10.8.0.1";
              };
              setup-sops = {
                type = "app";
                program = "${setupSopsApp}/bin/setup-sops";
                meta.description = "Generate sops-nix age key pair";
              };
              nixfleet = {
                type = "app";
                program = "${nixfleetPkgs.cli}/bin/nixfleet";
                meta.description = "nixfleet CLI (status, health)";
              };
              nixfleet-manifest = {
                type = "app";
                program = "${dotfilesLib.ciScripts.mkCheckApp {
                  name = "nixfleet-manifest";
                  buildTargets = [
                    ".#packages.x86_64-linux.nixfleet-manifest"
                    ".#packages.x86_64-linux.nixfleet-ui"
                  ];
                }}/bin/nixfleet-manifest";
                meta.description = "Evaluate the nixfleet artifacts";
              };
              menu = {
                type = "app";
                program = "${menuApp}/bin/menu";
                meta.description = "Interactive command launcher (fzf)";
              };
            };
          }
          // {
            checks =
              dotfilesChecks
              // {
                nixfleet-tests = nixfleetPkgs.tests;
              };
          };
      }
      // {
        flake = {
          lib = import ./lib/framework;

          nixosModules = {
            nixos = import ./modules/nixos/default.nix;
            home = import ./modules/home/default.nix;
          };

          nixosConfigurations = {
            x270 = x270-config;
            mireo = mireo-config;
          };

          nixfleetArtifacts = import ./nixfleet/manifest.nix {
            inherit (nixpkgs) lib;
            pkgs = pkgsForPatch;
            configurations = self.nixosConfigurations;
            deployNodes = self.deploy.nodes or {};
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
            x270 = {
              hostname = "localhost";
              sshUser = "root";
              profiles.system = {
                user = "root";
                path = activateNixosWithNixPath self.nixosConfigurations.x270;
              };
            };
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
