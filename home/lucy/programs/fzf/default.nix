# NOT AFFECTED by Lassulus/wrappers PR #135
# This wrapper uses pkgs.stdenvNoCC.mkDerivation directly, not the wrappers library.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "fzf-with-config";
  version = "0.1.0";

  src = pkgs.fzf;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    
    cp -r $src/bin $out/
    cp -r $src/shell $out/
    cp -r $src/man $out/
    cp -r $src/completion $out/
    
    export FZF_DEFAULT_COMMAND="fd --type f"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d"
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
    
    wrapProgram $out/bin/fzf \
      --set FZF_DEFAULT_COMMAND "$FZF_DEFAULT_COMMAND" \
      --set FZF_CTRL_T_COMMAND "$FZF_CTRL_T_COMMAND" \
      --set FZF_ALT_C_COMMAND "$FZF_ALT_C_COMMAND" \
      --set FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS"
  '';

  outputs = [ "out" ];
}
