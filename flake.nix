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
    yammat,
    deploy-rs,
    nix-topology,
    ewm,
    ...
  }: let
    pkgsForPatch = import nixpkgs {system = "x86_64-linux";};
    nixfleetPkgs = import ./nixfleet/default.nix {pkgs = pkgsForPatch;};
    # NOTE: nix-topology is used unpatched via inputs.nix-topology.flakeModule.
    # A previous ELK spacing tweak (nodeNode=120, see git history) was applied
    # via pkgs.applyPatches + import from derivation output, which is IFD and
    # breaks `nix flake show` (IFD is forbidden during flake listing).
    # Label overlap is still handled at build time by fix-network-svg post-processing
    # in packages.topology. Do not reintroduce applyPatches/import-from-derivation here.
    mkHost = {
      modules,
      specialArgs ? {},
    }:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit modules specialArgs;
      };

    frameworkLib = import ./lib/framework;

    p53SpecialArgs = {
      inherit wrappers stylix nix-flatpak nixos-hardware nixGaming frameworkLib ewm;
    };

    mireoSpecialArgs = {
      inherit wrappers yammat nixpkgs frameworkLib;
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
        ({lib, ...}: {
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
        ({lib, ...}: {
          lucy.nixfleet.api.package = lib.mkDefault nixfleetPkgs.api;
          lucy.nixfleet.agent.package = lib.mkDefault nixfleetPkgs.agent;
        })
      ];
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} (
      {
        imports = [nix-topology.flakeModule];
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
                inherit self pkgs p53-config;
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
            rebuild = "Rebuild local p53 via nh";
            "deploy-p53" = "Deploy p53 via deploy-rs to localhost";
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

          # Optional custom installer; mireo's default PXE uses netboot.xyz.
          # NixOS mit Xfce-Desktop als PXE-Netboot-Payload. iPXE kann die
          # ~2-GB-initrd NICHT laden (0x2a818006, contiguous-lowmem-Limit),
          # darum lädt GRUB als Zwischenlader (legt initrd oberhalb 4 GB ab):
          # Firmware → iPXE-Menü → grub.pxe/grubx64.efi (per TFTP), dann
          # Kernel+initrd per HTTP. Separates Paket (kein nixosConfiguration/
          # topology-Eintrag), damit mireo-Deploys nicht bei jedem Switch
          # das GB-große Installer-Closure bauen.
          # Sync nach dem Bauen: Dateien aus ./result nach mireo:/data/pxe
          # kopieren (Caddy serviert /boot/*; custom TFTP files need separate setup).
          # Secure Boot: Images unsigniert → auf physischen Zielen aus.
          pxeDesktop = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [./hosts/pxe-desktop];
          };
          # GRUB-Netboot-Menü (Prefix /boot/grub per TFTP, Kernel+initrd per
          # HTTP). Kernel-Params wie netboot.ipxe + serielle Konsole (VGA
          # bleibt primär). ASCII-only: Textmodus kann kein UTF-8.
          pxeGrubCfg = pkgs.writeText "grub.cfg" ''
            serial --unit=0 --speed=115200
            terminal_input console serial
            terminal_output console serial
            set timeout=8
            set default=0
            menuentry "NixOS Xfce-Desktop (Installer)" {
              linux (http,10.8.0.1)/boot/bzImage init=${pxeDesktop.config.system.build.toplevel}/init initrd=initrd ${pkgs.lib.concatStringsSep " " pxeDesktop.config.boot.kernelParams} console=tty0 console=ttyS0
              initrd (http,10.8.0.1)/boot/initrd
            }
          '';
          pxeDesktopBoot = pkgs.runCommand "pxe-desktop-boot" {} ''
            mkdir -p $out/boot/grub
            cp ${pxeDesktop.config.system.build.kernel}/${pxeDesktop.config.system.boot.loader.kernelFile} $out/bzImage
            cp ${pxeDesktop.config.system.build.netbootRamdisk}/initrd $out/initrd
            cp ${pxeDesktop.config.system.build.netbootIpxeScript}/netboot.ipxe $out/netboot.ipxe
            cp ${./hosts/pxe-desktop/menu.ipxe} $out/menu.ipxe
            # Startskript für lokale qemu-SLIRP-Tests (TFTP-bootfile, chainloadet
            # das HTTP-Menü; siehe hosts/pxe-desktop/slirp-boot.ipxe).
            cp ${./hosts/pxe-desktop/slirp-boot.ipxe} $out/slirp-boot.ipxe
            # Firmware startet iPXE für das Menü; nur NixOS lädt GRUB nach.
            cp ${pkgs.ipxe}/undionly.kpxe $out/undionly.kpxe
            cp ${pkgs.ipxe}/snp.efi $out/snp.efi
            cp ${pxeGrubCfg} $out/boot/grub/grub.cfg
            ${pkgs.grub2}/bin/grub-mkimage -O i386-pc-pxe -o $out/grub.pxe -p /boot/grub \
              pxe tftp http boot linux normal serial terminal reboot halt echo configfile search test true sleep
            ${pkgs.grub2_efi}/bin/grub-mkimage -O x86_64-efi -o $out/grubx64.efi -p /boot/grub \
              efinet tftp http boot linux normal serial terminal reboot halt echo configfile search test
          '';
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
              pxe-desktop-boot = pxeDesktopBoot;
            };

            apps = {
              rebuild = {
                type = "app";
                program = "${rebuildApp}/bin/rebuild";
                meta.description = "Rebuild the p53 host via nh";
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
              deploy-p53 = {
                type = "app";
                program = "${deployApp "p53"}/bin/deploy-p53";
                meta.description = "Deploy p53 via deploy-rs to localhost";
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
            p53 = p53-config;
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
