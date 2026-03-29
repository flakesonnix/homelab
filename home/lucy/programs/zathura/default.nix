# NOT AFFECTED by Lassulus/wrappers PR #135
# This wrapper uses pkgs.stdenvNoCC.mkDerivation directly, not the wrappers library.
{ pkgs ? import <nixpkgs> { } }:

let
  zathurarc = ''
    set zoom-step 10
    set pages-per-row 1
    set default-zoom fit-width
    set selection-clipboard clipboard
    set show-scrollbar false
    set window-title-basename true
    set synctex true
    set forward-search-command "nvim --remote-silent +%{line} %{input}"
    
    set font "Liberation Sans 12"
    set inputbar-bg "#282828"
    set inputbar-fg "#ebdbb2"
    set statusbar-bg "#282828"
    set statusbar-fg "#ebdbb2"
    set notification-bg "#282828"
    set notification-fg "#ebdbb2"
    set completion-bg "#282828"
    set completion-fg "#ebdbb2"
    set completion-highlight-bg "#504945"
    set completion-highlight-fg "#ebdbb2"
    set window-title-basename true
    set statusbar-basename true
  '';
in

pkgs.stdenvNoCC.mkDerivation {
  pname = "zathura-with-config";
  version = "0.1.0";

  src = pkgs.zathura;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/etc/xdg/zathura
    
    cp $src/bin/zathura $out/bin/zathura
    cp -r $src/lib $out/lib
    cp -r $src/share $out/share
    
    echo '${zathurarc}' > $out/etc/xdg/zathurarc
    
    wrapProgram $out/bin/zathura \
      --set XDG_CONFIG_HOME "$out/etc/xdl"
  '';

  outputs = [ "out" ];
}
