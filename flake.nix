{
  description = "NixOS dotfiles for lucy";

  nixConfig = {
    accept-flake-config = true;
    extra-substituters = [ "https://nix-gaming.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
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
      inputs.flake-parts.follows = "flake-parts";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixGaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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

    # EWM (Emacs Wayland Manager) compositor + NixOS module, pinned 2026-10-14.
    # Tarball input: lib.fileset.gitTracked evaluates store paths without
    # filtering, so no git checkout is needed.
    # Deliberately NOT following our nixpkgs (July 2026, libdisplay-info 0.2):
    # EWM pins libdisplay-info 0.3, which only its own locked nixpkgs provides.
    ewm = {
      url = "https://codeberg.org/ezemtsov/ewm/archive/a26d17f885f86b3e3adde7315c9720283820286f.tar.gz";
    };
  };

  # Custom flake outputs (intentional, used by external tools):
  # - deploy (deploy-rs): flake.deploy.nodes for `deploy .#<host>`
  # - topology (nix-topology): flake.topology for `nix build .#topology`
  # - nixfleetArtifacts (nixfleet): flake.nixfleetArtifacts for manifest/ui generation
  # Warnings about "unknown flake output" for these are expected and can be ignored;
  # they are not standard outputs like `packages` or `checks` but are required by
  # their respective tools. See docs/data-model.md and nixfleet/docs/architecture.md.
  outputs =
    inputs@{
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
      yammat,
      deploy-rs,
      nix-topology,
      ewm,
      ...
    }:
    let
      pkgsForPatch = import nixpkgs { system = "x86_64-linux"; };
      nixfleetPkgs = import ./nixfleet/default.nix { pkgs = pkgsForPatch; };
      # NOTE: nix-topology is used unpatched via inputs.nix-topology.flakeModule.
      # A previous ELK spacing tweak (nodeNode=120, see git history) was applied
      # via pkgs.applyPatches + import from derivation output, which is IFD and
      # breaks `nix flake show` (IFD is forbidden during flake listing).
      # Label overlap is still handled at build time by fix-network-svg post-processing
      # in packages.topology. Do not reintroduce applyPatches/import-from-derivation here.
      mkHost =
        {
          modules,
          specialArgs ? { },
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit modules specialArgs;
        };

      frameworkLib = import ./lib/framework;

      p53SpecialArgs = {
        inherit
          wrappers
          stylix
          nix-flatpak
          nixos-hardware
          nixGaming
          frameworkLib
          ewm
          ;
      };

      mireoSpecialArgs = {
        inherit
          wrappers
          yammat
          nixpkgs
          frameworkLib
          ;
      };

      p53-config = mkHost {
        specialArgs = p53SpecialArgs;
        modules = [
          ./nix-settings.nix
          ./profiles/desktop.nix
          ./hosts/p53
          ./modules/nixos/audio-stream.nix
          ./modules/nixos/epg-refresh.nix # services.epg-refresh: täglicher Jellyfin-XMLTV-Guide
          ./modules/nixos/fonts.nix
          ./modules/nixos/gaming.nix
          ./modules/nixos/gnome.nix
          ./modules/nixos/gnome-extensions.nix
          ./modules/nixos/plasma.nix
          ./modules/nixos/sunshine.nix
          ./modules/nixos/nvidia.nix
          ./modules/nixos/nvidia-resume.nix
          ./modules/nixos/niri.nix
          ./modules/nixos/ewm.nix
          ewm.nixosModules.default
          ./modules/nixos/serial-getty.nix
          ./modules/nixos/sops.nix
          ./modules/nixos/waybar.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          lanzaboote.nixosModules.lanzaboote
          ({ lib, ... }: {
            boot.loader.systemd-boot.enable = lib.mkForce false;
            boot.lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";
              # /boot ist nur 1 GB, ein initrd allein ~218 MB: höchstens 3
              # Generationen behalten, sonst läuft die ESP wieder voll (ENOSPC
              # bei Gen 240, Okt 2026).
              configurationLimit = 3;
            };
          })
          ./modules/nixos/hm-base.nix
          ./modules/nixos/deskflow.nix
          ./modules/nixos/waydroid.nix
          ./modules/nixos/nixfleet.nix
          run0-sudo-shim.nixosModules.default
          ({ lib, ... }: {
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
          ./modules/nixos/asterisk.nix
          ./modules/nixos/voip.nix # services.voip SIP abstraction (eventphone 4309 live)
          ./modules/nixos/uptime-kuma-sync.nix # services.uptime-kuma-sync declarative monitors
          ./modules/nixos/nixfleet.nix
          ./modules/nixos/sops.nix
          # ── Homelab platform modules ──────────────
          ./modules/nixos/postgres.nix
          ./modules/nixos/identity-openldap.nix
          ./modules/nixos/identity-keycloak.nix
          ./modules/nixos/dns-adguard.nix
          ./modules/nixos/reverse-proxy.nix
          ./modules/nixos/nextcloud.nix
          ./modules/nixos/syncthing.nix
          ./modules/nixos/immich.nix
          ./modules/nixos/paperless.nix
          ./modules/nixos/woodpecker.nix
          ./modules/nixos/hydra.nix
          ./modules/nixos/registry.nix
          ./modules/nixos/attic.nix
          ./modules/nixos/netbox.nix
          ./modules/nixos/librenms.nix
          ./modules/nixos/matrix.nix
          ./modules/nixos/ntfy.nix
          ./modules/nixos/rustdesk.nix
          ./modules/nixos/osm.nix
          ./modules/nixos/minecraft.nix # lucy.services.minecraft (~/mcserver wrapper)
          ./modules/nixos/mopidy.nix # lucy.services.mopidy (music server, host ALSA)
          sops-nix.nixosModules.sops
          run0-sudo-shim.nixosModules.default
          ({ lib, ... }: {
            lucy.nixfleet.api.package = lib.mkDefault nixfleetPkgs.api;
            lucy.nixfleet.agent.package = lib.mkDefault nixfleetPkgs.agent;
          })
        ];
      };
      # scaffold:host-definitions
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        imports = [ nix-topology.flakeModule ];
        systems = [ "x86_64-linux" ];

        perSystem =
          {
            system,
            pkgs,
            ...
          }:
          let
            dotfilesLib = import ./lib/default.nix pkgs;
            formatting = import ./lib/formatting.nix { inherit pkgs; };
            # Framework template checks that target components this repo
            # doesn't ship are excluded from the aggregate CI bundle.
            frameworkChecks =
              builtins.removeAttrs
                (import ./lib/framework/flake/checks.nix {
                  inherit self pkgs p53-config;
                }).checks
                [ "webui-unit" ];
            deployChecks = deploy-rs.lib.${system}.deployChecks self.deploy;
            dotfilesChecks =
              import ./tests/default.nix {
                inherit pkgs microvm self;
                inherit (pkgs) lib;
              }
              // {
                formatting = formatting.check self;
                repository = import ./tests/repository.nix { inherit pkgs self; };
              };
            dwlScroll = pkgs.callPackage ./pkgs/dwl-scroll { };
            dwlScrollChecks = {
              dwl-scroll = dwlScroll;
              dwl-scroll-no-xwayland = dwlScroll.override { enableXWayland = false; };
              dwl-scroll-module = import ./tests/dwl-scroll.nix { inherit pkgs self; };
              dwl-scroll-headless = import ./tests/dwl-scroll-headless.nix {
                inherit pkgs;
                package = dwlScroll;
              };
              dwl-scroll-settings = import ./tests/dwl-scroll-settings.nix {
                inherit pkgs;
                inherit (pkgs) lib;
              };
            };
            fullCiChecks = dotfilesLib.ciScripts.mkCiCheckBundle {
              checks = frameworkChecks // deployChecks // dotfilesChecks // dwlScrollChecks;
            };
            nixfleetPkgs = import ./nixfleet/default.nix { inherit pkgs; };
          in
          {
            formatter = formatting.formatter;

            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                nixfmt
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

            topology.modules = [ ./topology.nix ];
            topology.nixosConfigurations = builtins.mapAttrs (
              _: cfg:
              cfg.extendModules {
                modules = [
                  nix-topology.nixosModules.default
                  ./modules/nixos/topology.nix
                ];
              }
            ) self.nixosConfigurations;

            packages = {
              full-ci-checks = fullCiChecks;
              topology = pkgs.runCommand "topology-fixed" { } ''
                cp -r ${self.topology.x86_64-linux.config.output} $out
                chmod +w $out $out/network.svg
                ${dotfilesLib.topologyScripts.fixNetworkSvgApp { }}/bin/fix-network-svg $out/network.svg
              '';
              nixfleet-api = nixfleetPkgs.api;
              nixfleet-agent = nixfleetPkgs.agent;
              nixfleet = nixfleetPkgs.cli;
              nixfleet-web = nixfleetPkgs.web;
              nixfleet-manifest = pkgs.writeText "manifest.json" self.nixfleetArtifacts.manifestJson;
              nixfleet-ui = pkgs.writeText "ui.json" self.nixfleetArtifacts.uiJson;
              dwl-scroll = dwlScroll;
              lucy-ca = pkgs.callPackage ./pkgs/lucy-ca { };
              pxe-desktop-boot = import ./hosts/pxe-desktop/boot.nix { inherit pkgs nixpkgs; };
            };

            apps = import ./flake/apps.nix {
              inherit
                pkgs
                system
                deploy-rs
                nixfleetPkgs
                dotfilesLib
                ;
            };
          }
          // {
            checks =
              dotfilesChecks
              // dwlScrollChecks
              // {
                nixfleet-tests = nixfleetPkgs.tests;
              };
          };
      }
      // {
        flake = {
          lib = import ./lib/framework;

          nixosModules = {
            lucy-ca = import ./modules/nixos/lucy-ca.nix;
            dwl-scroll = import ./modules/nixos/dwl-scroll.nix;
            nixos = import ./modules/nixos/default.nix;
            home = import ./modules/home/default.nix;
          };

          nixosConfigurations = {
            p53 = p53-config;
            mireo = mireo-config;
            # scaffold:host-registrations
          };

          nixfleetArtifacts = import ./nixfleet/manifest.nix {
            inherit (nixpkgs) lib;
            pkgs = pkgsForPatch;
            configurations = self.nixosConfigurations;
            deployNodes = self.deploy.nodes or { };
          };

          deploy.nodes =
            let
              # nixos-rebuild-ng reexec step runs `nix-build '<nixpkgs/nixos>'` which
              # needs nixos-config in NIX_PATH. Flake-only systems don't set it.
              # Wrap switch-to-configuration with a stub nixos-config until
              # nix-settings.nix's environment.etc entry propagates via a reboot.
              activateNixosWithNixPath =
                nixosConfig:
                let
                  stub = nixpkgs.legacyPackages.x86_64-linux.writeText "nixos-config.nix" "{ ... }: { }";
                  nixPathEnv = "NIX_PATH=nixpkgs=flake:nixpkgs:nixos-config=${stub}";
                in
                (
                  deploy-rs.lib.x86_64-linux.activate.custom
                  // {
                    dryActivate = "${nixPathEnv} $PROFILE/bin/switch-to-configuration dry-activate";
                    boot = "${nixPathEnv} $PROFILE/bin/switch-to-configuration boot";
                  }
                )
                  nixosConfig.config.system.build.toplevel
                  "${nixPathEnv} $PROFILE/bin/switch-to-configuration switch";
            in
            {
              p53 = {
                hostname = "localhost";
                sshUser = "root";
                profiles.system = {
                  user = "root";
                  path = activateNixosWithNixPath self.nixosConfigurations.p53;
                };
              };
              mireo = {
                hostname = "10.8.0.1";
                sshUser = "root";
                # Build on the target (fetches deps via its own substituters)
                # instead of copying the locally-built closure over the LAN.
                remoteBuild = true;
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
