{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "dotfiles-docs";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    pandoc
    librsvg
  ];

  buildPhase = ''
    mkdir -p $out/html

    # Build HTML
    pandoc \
      --standalone \
      --toc \
      --toc-depth=3 \
      --metadata-file=metadata.yaml \
      -t html5 \
      -o $out/html/index.html \
      architecture.md
  '';

  installPhase = ''
    mkdir -p $out
  '';

  outputs = [ "out" ];
}
