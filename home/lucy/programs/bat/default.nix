# NOT AFFECTED by Lassulus/wrappers PR #135
# This wrapper uses pkgs.stdenvNoCC.mkDerivation directly, not the wrappers library.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "bat-with-config";
  version = "0.1.0";

  src = pkgs.bat;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    
    cp $src/bin/bat $out/bin/bat
    cp -r $src/lib $out/lib
    cp -r $src/share $out/share
    
    wrapProgram $out/bin/bat \
      --set BAT_THEME "OneHalfDark" \
      --set BAT_STYLE "header,changes,rule" \
      --set BAT_TABS "2"
  '';

  outputs = [ "out" ];
}
