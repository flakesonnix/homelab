# nixfleet package derivations. M0: stdlib-only Go binaries + Vite frontend +
# Nix-generated artifacts. Binaries keep the flake's repo paths stable; all
# structure (UI, plugins, routes) comes from the artifacts, not from Go.
{pkgs}: let
  src = ./.;

  goBuild = {
    pkg,
    binary,
    ...
  } @ args:
    pkgs.buildGoModule (
      {
        pname = binary;
        version = "0.1.0";
        inherit src;
        vendorHash = null;
        subPackages = [pkg];
        ldflags = ["-s" "-w"];
        postInstall = ''
          mv $out/bin/${baseNameOf pkg} $out/bin/${binary}
        '';
        meta.mainProgram = binary;
      }
      // builtins.removeAttrs args ["pkg" "binary"]
    );
in {
  api = goBuild {
    pkg = "api";
    binary = "nixfleet-api";
  };
  agent = goBuild {
    pkg = "agent";
    binary = "nixfleet-agent";
  };
  cli = goBuild {
    pkg = "cli";
    binary = "nixfleet";
  };

  tests = goBuild {
    pkg = "api";
    binary = "nixfleet-tests";
    doCheck = true;
    checkPhase = "go vet ./... && go test ./...";
  };

  web = pkgs.buildNpmPackage {
    pname = "nixfleet-web";
    version = "0.1.0";
    src = ./web/frontend;
    nodejs = pkgs.nodejs_22;
    npmDepsHash = "sha256-uE9e7fPpYT9Jyuf2D/yxPpTJ9D3F2zLGYoDL6ga2NJg=";
    buildPhase = "npm run build";
    installPhase = "mkdir -p $out && cp -r dist/* $out/";
  };
}
