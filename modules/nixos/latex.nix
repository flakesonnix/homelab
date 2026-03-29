{ lib, config, pkgs, ... }:

{
  options.p50 = {
    latex = {
      enable = lib.mkEnableOption "LaTeX writing environment";
    };
  };

  config = lib.mkIf config.p50.latex {
    environment.systemPackages = with pkgs; [
      texliveSmall
      latexmk
      biber
      texlab
      zathura
    ];
  };
}
