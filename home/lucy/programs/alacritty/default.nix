# NOT AFFECTED by Lassulus/wrappers PR #135
# This wrapper uses pkgs.stdenvNoCC.mkDerivation directly, not the wrappers library.
{ pkgs ? import <nixpkgs> { } }:

let
  alacrittyConfig = ''
    font:
      normal:
        family: "Hack"
        style: Regular
      bold:
        family: "Hack"
        style: Bold
      italic:
        family: "Hack"
        style: Italic
      size: 18

    colors:
      primary:
        background: '#282828'
        foreground: '#ebdbb2'
      cursor:
        text: '#282828'
        cursor: '#ebdbb2'
      normal:
        black:   '#282828'
        red:     '#cc241d'
        green:   '#98971a'
        yellow:  '#d79921'
        blue:    '#458588'
        magenta: '#b16286'
        cyan:    '#689d6a'
        white:   '#a89984'
      bright:
        black:   '#928374'
        red:     '#fb4934'
        green:   '#b8bb26'
        yellow:  '#fabd2f'
        blue:    '#83a598'
        magenta: '#d3869b'
        cyan:    '#8ec07c'
        white:   '#ebdbb2'

    window:
      opacity: 0.9
      padding:
        x: 10
        y: 10
      dynamic_padding: true

    scrolling:
      history: 10000

    cursor:
      style:
        shape: Block
        blinking: On
      unfocused_hollow: true
  '';
in

pkgs.stdenvNoCC.mkDerivation {
  pname = "alacritty-with-config";
  version = "0.1.0";

  src = pkgs.alacritty;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/etc/xdg/alacritty
    
    cp $src/bin/alacritty $out/bin/alacritty
    cp -r $src/lib $out/lib
    cp -r $src/share $out/share
    
    echo '${alacrittyConfig}' > $out/etc/xdg/alacritty/alacritty.yml
    
    wrapProgram $out/bin/alacritty \
      --set XDG_CONFIG_HOME "$out/etc/xdl"
  '';

  outputs = [ "out" ];
}
