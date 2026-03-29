{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "dotfiles-docs";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    pandoc
    texliveMinimal
    librsvg
  ];

  buildPhase = ''
    mkdir -p $out/html $out/pdf $out/epub

    # Build HTML
    pandoc \
      --standalone \
      --toc \
      --toc-depth=3 \
      --metadata-file=docs/metadata.yaml \
      -t html5 \
      -o $out/html/index.html \
      README.md \
      docs/architecture.md

    # Build PDF
    pandoc \
      --toc \
      --toc-depth=3 \
      --metadata-file=docs/metadata.yaml \
      -t pdf \
      -o $out/pdf/dotfiles.pdf \
      README.md \
      docs/architecture.md

    # Build EPUB  
    pandoc \
      --toc \
      --toc-depth=3 \
      --metadata-file=docs/metadata.yaml \
      -t epub3 \
      -o $out/epub/dotfiles.epub \
      README.md \
      docs/architecture.md
  '';

  installPhase = ''
    mkdir -p $out
  '';

  outputs = [ "out" ];
}
