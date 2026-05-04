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
          config,
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
          devshells.default = {
            name = "dotfiles";
            packages = with pkgs; [
              config.flake-root.package
              nixpkgs-fmt
              pkgs.alejandra
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
              {
                name = "rebuild";
                command = "nh os switch";
                help = "Rebuild omen host";
              }
              {
                name = "update";
                command = "nix flake update";
                help = "Update flake inputs";
              }
              {
                name = "fmt";
                command = "nix fmt";
                help = "Format the repository";
              }
              {
                name = "check";
                command = "nix flake check";
                help = "Check the flake";
              }
            ];
          };

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

           checks = {
            no-plaintext-host-passwords =
              pkgs.runCommand "no-plaintext-host-passwords" {
                nativeBuildInputs = [pkgs.ripgrep];
                src = self;
              } ''
                # Catch obvious plaintext creds in declarative host data.
                # Limit scope to data/hosts to avoid false positives in module docs.
                rg -n --hidden --no-ignore-vcs 'password\s*=\s*"' "$src/data/hosts" && exit 1
                mkdir -p "$out"
              '';

            webui-unit =
              pkgs.runCommand "webui-unit" {
                nativeBuildInputs = [pkgs.rustc pkgs.stdenv.cc];
                src = self;
              } ''
                rustc --test "$src/webui/src/http.rs" -o http-tests
                ./http-tests
                rustc --test "$src/webui/src/model.rs" -o model-tests
                ./model-tests
                rustc --test "$src/webui/src/state.rs" -o state-tests
                ./state-tests
                rustc --test "$src/webui/src/tests.rs" -o webui-tests
                ./webui-tests
                mkdir -p "$out"
              '';

            framework-validation =
              pkgs.runCommand "framework-validation" {
                nativeBuildInputs = [pkgs.nix];
                src = self;
              } ''
                export HOME="$TMPDIR"
                export XDG_STATE_HOME="$TMPDIR/state"
                cat > validation-test.nix <<EOF
                let
                  pkgs = import ${pkgs.path} {};
                  lib = pkgs.lib;
                  dot = import ${framework.outPath}/lib;
                  validation = dot.core.validation;
                  host = validation.validateHost {
                    inherit lib;
                    hostRoot = $src/data/hosts/omen;
                    roleRoot = $src/data/roles;
                    presetRoot = $src/data/presets;
                  };
                  home = validation.validateHome {
                    inherit lib;
                    homeRoot = $src/data/home/lucy;
                    roleRoot = $src/data/roles;
                    bundleRoot = $src/data/bundles;
                  };
                in
                  assert host.missingRoles == [];
                  assert host.missingPresets == [];
                  assert home.missingRoles == [];
                  assert home.missingBundles == [];
                  true
                EOF
                nix-instantiate --eval --expr "import ./validation-test.nix"
                mkdir -p "$out"
              '';

            framework-unit =
              pkgs.runCommand "framework-unit" {
                nativeBuildInputs = [pkgs.nix];
                src = self;
              } ''
                export HOME="$TMPDIR"
                export XDG_STATE_HOME="$TMPDIR/state"
                fixture="$TMPDIR/framework-fixture"
                mkdir -p "$fixture/data/roles" "$fixture/data/presets" "$fixture/data/bundles" "$fixture/data/hosts/omen" "$fixture/data/home/lucy" "$fixture/data/home/broken"

                cat > "$fixture/data/roles/base.nix" <<'EOF'
                {
                  meta = {
                    description = "Base role";
                    targets = ["host" "home"];
                  };

                  host = {
                    presets = ["base"];
                  };

                  home = {
                    bundles = ["core"];
                  };
                }
                EOF

                cat > "$fixture/data/roles/desktop.nix" <<'EOF'
                {
                  meta = {
                    description = "Desktop role";
                    targets = ["host" "home"];
                    requires = {
                      host = ["base"];
                      home = ["base"];
                    };
                    conflicts = {
                      host = ["server"];
                    };
                  };

                  host = {
                    presets = ["desktop"];
                  };

                  home = {
                    bundles = ["desktop"];
                  };
                }
                EOF

                cat > "$fixture/data/roles/server.nix" <<'EOF'
                {
                  meta = {
                    description = "Server role";
                    targets = ["host"];
                  };

                  host = {
                    presets = [];
                  };
                }
                EOF

                cat > "$fixture/data/presets/base.nix" <<'EOF'
                {
                  meta = {
                    description = "Base preset";
                    targets = ["host"];
                  };

                  basePackages = ["base-tool"];
                }
                EOF

                cat > "$fixture/data/presets/desktop.nix" <<'EOF'
                {
                  meta = {
                    description = "Desktop preset";
                    targets = ["host"];
                  };

                  moduleFlags = {
                    lucy.desktop.enable = true;
                  };

                  packageTags = ["browser"];

                  systemPackages = ["desktop-tool"];
                }
                EOF

                cat > "$fixture/data/presets/manual-host.nix" <<'EOF'
                {
                  meta = {
                    description = "Manual host preset";
                    targets = ["host"];
                  };

                  settings = {
                    test.manualHost = true;
                  };
                }
                EOF

                cat > "$fixture/data/bundles/core.nix" <<'EOF'
                {
                  meta = {
                    description = "Core bundle";
                    targets = ["home"];
                  };

                  programs.core.enable = true;
                }
                EOF

                cat > "$fixture/data/bundles/desktop.nix" <<'EOF'
                {
                  meta = {
                    description = "Desktop bundle";
                    targets = ["home"];
                  };

                  programs.desktop.enable = true;
                }
                EOF

                cat > "$fixture/data/bundles/manual.nix" <<'EOF'
                {
                  meta = {
                    description = "Manual bundle override";
                    targets = ["home"];
                  };

                  packageToggles = ["comma"];

                  programs.manual.enable = true;
                }
                EOF

                cat > "$fixture/data/hosts/omen/roles.nix" <<'EOF'
                [
                  "base"
                  "desktop"
                ]
                EOF

                cat > "$fixture/data/hosts/omen/presets.nix" <<'EOF'
                [
                  "manual-host"
                ]
                EOF

                cat > "$fixture/data/home/lucy/roles.nix" <<'EOF'
                [
                  "base"
                  "desktop"
                ]
                EOF

                cat > "$fixture/data/home/lucy/bundles.nix" <<'EOF'
                [
                  "manual"
                ]
                EOF

                cat > "$fixture/data/home/broken/roles.nix" <<'EOF'
                [
                  "desktop"
                ]
                EOF

                cat > framework-unit-test.nix <<EOF
                let
                  pkgs = import ${pkgs.path} {};
                  lib = pkgs.lib;
                  dot = import ${framework.outPath}/lib;
                  validation = dot.core.validation;
                  export = dot.framework.export;
                  hostFramework = dot.framework.host;
                  homeFramework = dot.framework.home;
                  resolve = dot.framework.resolve;
                  fixture = $fixture;

                  metadata = export.exportMetadata fixture;
                  preview = export.exportPreview fixture;

                  hostValidation = validation.validateHost {
                    inherit lib;
                    hostRoot = fixture + "/data/hosts/omen";
                    roleRoot = fixture + "/data/roles";
                    presetRoot = fixture + "/data/presets";
                    packageRegistry = {
                      firefox = {tags = ["browser"];};
                    };
                    packageData = {
                      packageToggles = ["firefox"];
                      packageTags = ["browser"];
                    };
                  };

                  homeValidation = validation.validateHome {
                    inherit lib;
                    homeRoot = fixture + "/data/home/broken";
                    roleRoot = fixture + "/data/roles";
                    bundleRoot = fixture + "/data/bundles";
                    packageRegistry = {
                      comma = {tags = ["cli"];};
                    };
                    packageData = {
                      packageToggles = ["comma"];
                    };
                  };

                  failingAssertion = builtins.tryEval (validation.assertValid {
                    inherit lib;
                    missingBundles = ["manual"];
                  });

                  flattened = validation.flattenModuleFlags {
                    lucy.desktop.enable = true;
                    programs.foo.enable = false;
                  };

                  invalidFlags = validation.invalidModuleFlagKeys {
                    moduleFlags = {
                      foo = true;
                      "bad-root" = {
                        enable = true;
                      };
                      programs.good.enable = true;
                    };
                    allowedRoots = ["programs" "services" "home" "lucy"];
                  };

                  conflicts = validation.collectModuleFlagConflicts [
                    {moduleFlags.programs.foo.enable = true;}
                    {moduleFlags.programs.foo.enable = false;}
                    {moduleFlags.services.bar.enable = true;}
                  ];

                  resolvedHostPresets = resolve.resolveHostPresets {
                    directPresets = ["manual-host"];
                    roles = [
                      {presets = ["base" "desktop"];}
                      {presets = ["desktop"];}
                    ];
                  };

                  resolvedHomeBundles = resolve.resolveHomeBundles {
                    directBundles = ["manual"];
                    roles = [
                      {bundles = ["core"];}
                      {bundles = ["desktop"];}
                    ];
                  };

                  appliedHost = hostFramework.applyHost {
                    inherit lib;
                    host = {
                      __root = fixture + "/data/hosts/omen";
                      roles = ["base" "desktop"];
                      presets = ["manual-host"];
                    };
                    roleRoot = fixture + "/data/roles";
                    presetRoot = fixture + "/data/presets";
                    packageRegistry = {
                      firefox = {
                        tags = ["browser"];
                      };
                    };
                    packagePath = ["testPkgs"];
                    basePackagePath = ["testBase"];
                    systemPackagePath = ["testSystem"];
                  };

                  appliedHome = homeFramework.applyHome {
                    inherit lib;
                    home = {
                      __root = fixture + "/data/home/lucy";
                      roles = ["base" "desktop"];
                      bundles = ["manual"];
                    };
                    roleRoot = fixture + "/data/roles";
                    bundleRoot = fixture + "/data/bundles";
                    packageRegistry = {
                      comma = {
                        tags = ["cli"];
                      };
                    };
                    packagePath = ["testHomePkgs"];
                  };

                  duplicateHostPresetFailure = builtins.tryEval (hostFramework.applyHost {
                    inherit lib;
                    host = {
                      __root = fixture + "/data/hosts/omen";
                      roles = ["base"];
                      presets = ["manual-host" "manual-host"];
                    };
                    roleRoot = fixture + "/data/roles";
                    presetRoot = fixture + "/data/presets";
                    packagePath = ["testPkgs"];
                    basePackagePath = ["testBase"];
                  });

                  duplicateHomeBundleFailure = builtins.tryEval (homeFramework.applyHome {
                    inherit lib;
                    home = {
                      __root = fixture + "/data/home/lucy";
                      roles = ["desktop"];
                      bundles = ["manual" "manual"];
                    };
                    roleRoot = fixture + "/data/roles";
                    bundleRoot = fixture + "/data/bundles";
                    packagePath = ["testHomePkgs"];
                  });
                in
                  assert validation.normalizeRoleList ["base"] == ["base"];
                  assert validation.normalizeRoleList {roles = ["base" "desktop"];} == ["base" "desktop"];
                  assert builtins.attrNames flattened == ["lucy.desktop.enable" "programs.foo.enable"];
                  assert flattened."lucy.desktop.enable" == true;
                  assert flattened."programs.foo.enable" == false;
                  assert conflicts == ["programs.foo.enable"];
                  assert resolvedHostPresets == ["manual-host" "base" "desktop"];
                  assert resolvedHomeBundles == ["manual"];
                  assert invalidFlags == ["bad-root.enable" "foo"];
                  assert failingAssertion.success == false;
                  assert appliedHost.lucy.desktop.enable == true;
                  assert appliedHost.testPkgs.firefox == true;
                  assert appliedHost.testBase == ["base-tool"];
                  assert appliedHost.testSystem == ["desktop-tool"];
                  assert appliedHost.test.manualHost == true;
                  assert appliedHome.testHomePkgs.comma == true;
                  assert appliedHome.programs.manual.enable == true;
                  assert lib.hasAttrByPath ["programs" "desktop" "enable"] appliedHome == false;
                  assert duplicateHostPresetFailure.success == false;
                  assert duplicateHomeBundleFailure.success == false;
                  assert hostValidation.missingRoles == [];
                  assert hostValidation.missingPresets == [];
                  assert hostValidation.missingRequiredRoles == [];
                  assert hostValidation.conflictingRoles == [];
                  assert hostValidation.missingPackageToggles == [];
                  assert hostValidation.missingPackageTags == [];
                  assert homeValidation.missingRoles == [];
                  assert homeValidation.missingBundles == [];
                  assert homeValidation.missingRequiredRoles == ["desktop requires base"];
                  assert lib.hasInfix "role\tdesktop\tDesktop role\thost,home\tdesktop\tdesktop\tbase\tbase\tserver\t" metadata;
                  assert lib.hasInfix "preset\tmanual-host\tManual host preset\thost" metadata;
                  assert lib.hasInfix "bundle\tmanual\tManual bundle override\thome" metadata;
                  assert lib.hasInfix "preview-host-roles\tbase,desktop" preview;
                  assert lib.hasInfix "preview-host-presets\tmanual-host,base,desktop" preview;
                  assert lib.hasInfix "preview-home-roles\tbase,desktop" preview;
                  assert lib.hasInfix "preview-home-bundles\tmanual" preview;
                  true
                EOF
                nix-instantiate --eval --expr "import ./framework-unit-test.nix"
                mkdir -p "$out"
              '';

            # Force evaluation of full NixOS+HM config (no system build).
            # Discard string context so we don't pull huge build deps into this check.
            omen-eval = pkgs.writeText "omen-eval" (builtins.unsafeDiscardStringContext (builtins.toString omen-config.config.system.build.toplevel));
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
