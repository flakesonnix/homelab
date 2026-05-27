{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) lib;
  layout = import ./lib/layout.nix {inherit lib;};
  dashboard = import ./lib/pages/dashboard.nix {inherit lib;};
  rolesHost = import ./lib/pages/roles-host.nix {inherit lib;};
  rolesHome = import ./lib/pages/roles-home.nix {inherit lib;};
  presets = import ./lib/pages/presets.nix {inherit lib;};
  bundles = import ./lib/pages/bundles.nix {inherit lib;};

  webuiFiles =
    pkgs.runCommand "webui-files" {
      buildInputs = [pkgs.python3];
    } ''
          mkdir -p $out/lib/pages $out/bin

          cat > $out/lib/pages/index.html <<'EOFDASH'
      ${dashboard}
      EOFDASH

          cat > $out/lib/pages/roles-host.html <<'EOFHOST'
      ${rolesHost}
      EOFHOST

          cat > $out/lib/pages/roles-home.html <<'EOFHOME'
      ${rolesHome}
      EOFHOME

          cat > $out/lib/pages/presets.html <<'EOFPRE'
      ${presets}
      EOFPRE

          cat > $out/lib/pages/bundles.html <<'EOFBUN'
      ${bundles}
      EOFBUN

          cp ${./static/style.css} $out/lib/pages/style.css

          cat > $out/bin/nixfiles-webui <<'EOFSCRIPT'
      #!/usr/bin/env bash
      echo "Starting nixfiles-webui on http://127.0.0.1:8080"
      cd "$(dirname "$0")/../lib/pages"
      exec ${pkgs.python3}/bin/python3 -m http.server 8080
      EOFSCRIPT
          chmod +x $out/bin/nixfiles-webui
    '';
in
  webuiFiles.overrideAttrs (old: {
    meta.mainProgram = "nixfiles-webui";
  })
