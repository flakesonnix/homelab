{pkgs ? import <nixpkgs> {}}:

let
  layout = import ./lib/layout.nix {};
  dashboard = import ./lib/pages/dashboard.nix {};
  rolesHost = import ./lib/pages/roles-host.nix {};
  rolesHome = import ./lib/pages/roles-home.nix {};
  presets = import ./lib/pages/presets.nix {};
  bundles = import ./lib/pages/bundles.nix {};

  serverScript = pkgs.writeScriptBin "nixfiles-webui" ''
    #!/usr/bin/env bash
    set -euo pipefail
    PORT=8080
    WEBUI_ROOT="$(cd "$(dirname "$0")" && pwd)"
    exec socat "TCP-LISTEN:$PORT,reuseaddr,fork" "EXEC:$0,派的内斯1"
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "nixfiles-webui";
  version = "0.1.0";
  src = ./.;

  buildPhase = ''
    mkdir -p $out/lib/pages $out/static $out/bin

    echo "$dashboard" > $out/index.html
    echo "$rolesHost" > $out/lib/pages/roles-host.html
    echo "$rolesHome" > $out/lib/pages/roles-home.html
    echo "$presets" > $out/lib/pages/presets.html
    echo "$bundles" > $out/lib/pages/bundles.html

    cp static/style.css $out/static/
    cp server $out/server
    chmod +x $out/server $out/bin/nixfiles-webui
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -r . $out
  '';

  meta = {
    mainProgram = "nixfiles-webui";
  };
}