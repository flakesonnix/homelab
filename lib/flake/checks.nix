{
  self,
  pkgs,
  framework,
  omen-config,
  ...
}:
{
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
}