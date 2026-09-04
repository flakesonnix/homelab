{
  description = "Purr — Lucy's Nix DSL compiler (Zig 0.16)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = let
      purr = pkgs.stdenv.mkDerivation {
        pname = "purr";
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [pkgs.zig];
        buildPhase = ''
          zig build --global-cache-dir $TMPDIR/zig-global-cache -Doptimize=ReleaseSafe
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp zig-out/bin/purr $out/bin/
          cp zig-out/bin/purrc $out/bin/
        '';
      };
    in {
      default = purr;
      purr = purr;
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        zig
        alejandra
      ];
      shellHook = ''
        echo "purr devShell — zig $(zig version) — run 'zig build' / 'zig build test'"
      '';
    };

    checks.${system}.purr-tests = pkgs.stdenv.mkDerivation {
      name = "purr-tests";
      src = ./.;
      nativeBuildInputs = [pkgs.zig];
      buildPhase = ''
        zig build test --global-cache-dir $TMPDIR/zig-global-cache
      '';
      installPhase = ''touch $out'';
    };
  };
}
