{ lib, config, pkgs, ... }:

{
  options.lucy.latex = {
    enable = lib.mkEnableOption "LaTeX writing environment";
  };

  config = lib.mkIf config.lucy.latex.enable {
    environment.systemPackages = with pkgs; [
      texliveSmall
      texlivePackages.latexmk
      biber
      texlab
      zathura
    ];
  };
}
