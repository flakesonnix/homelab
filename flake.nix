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

    alejandra = {
      url = "github:Kamadorueda/alejandra";
    };

    haumea = {
      url = "github:nix-community/haumea";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-health = {
      url = "github:juspay/nix-health";
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

    framework = {
      url = "github:flakesonnix/rivotril";
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
    treefmt-nix,
    pre-commit-hooks,
    run0-sudo-shim,
    nixos-hardware,
    nixGaming,
    nur,
    framework,
    ...
  }: let
    omen-config = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit wrappers comfyui-nix stylix nix-flatpak nix-index-database nixos-hardware nixGaming;
        frameworkLib = framework.lib;
      };
      modules = [
        ./nix-settings.nix
        ./profiles/desktop.nix
        ./hosts/omen
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        lanzaboote.nixosModules.lanzaboote
        nur.modules.nixos.default
        ({
          lib,
          pkgs,
          ...
        }: {
          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
          };
          environment.systemPackages = [pkgs.sbctl];
        })
        ./modules/nixos/hm-base.nix
        run0-sudo-shim.nixosModules.default
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
          checkApp = pkgs.writeShellApplication {
            name = "check";
            text = "nix flake check";
          };
          updateApp = pkgs.writeShellApplication {
            name = "update";
            text = "nix flake update";
          };
        in {
          formatter = pkgs.alejandra;

          packages.webui = pkgs.stdenv.mkDerivation {
            pname = "nixfiles-webui";
            version = "0.1.0";
            src = ./webui;
            nativeBuildInputs = with pkgs; [meson ninja rustc cargo];
            configurePhase = ''
              meson setup build --prefix=$out
            '';
            buildPhase = ''
              ninja -C build
            '';
            installPhase = ''
              ninja -C build install
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
            update = {
              type = "app";
              program = "${updateApp}/bin/update";
              meta.description = "Update flake inputs";
            };
          };
        }
        // (import "${framework.outPath}/lib/flake/checks.nix" {
          inherit self pkgs framework omen-config;
        })
        // {
          checks = {
            webui-html-validate = pkgs.runCommand "webui-html-validate" {
              nativeBuildInputs = [pkgs.python3];
              src = self;
            } ''
              for f in $src/webui/lib/pages/*.nix; do
                if grep -q 'import.*layout.nix' "$f"; then
                  echo "Checking $f..."
                fi
              done
              python3 -c "
import os
import re

pages_dir = '$src/webui/lib/pages'
layout_file = '$src/webui/lib/layout.nix'

if not os.path.exists(layout_file):
    exit('Error: layout.nix not found')

for f in os.listdir(pages_dir):
    if not f.endswith('.nix'):
        continue
    path = os.path.join(pages_dir, f)
    with open(path) as fp:
        content = fp.read()
        if 'import' not in content or 'layout.nix' not in content:
            print(f'Warning: {f} may not import layout.nix')
"
              mkdir -p "$out"
            '';
          };
        };
      }
      // {
        flake = {
          inherit (framework) lib;

          nixosConfigurations = {
            omen = omen-config;
          };
        };
      }
    );
}
