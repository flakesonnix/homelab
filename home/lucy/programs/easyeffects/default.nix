{ config, pkgs, lib, ... }:

let
  presets = pkgs.stdenvNoCC.mkDerivation {
    pname = "easyeffects-presets";
    version = "1.0";

    src = pkgs.fetchFromGitHub {
      owner = "JackHack96";
      repo = "EasyEffects-Presets";
      rev = "master";
      sha256 = "0kqpqil43iab2776k3k2hd5nfg3lkfwm046wvjwx4hw8c5lrhm7n";
    };

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/output
      mkdir -p $out/irs

      cp output/*.json $out/output/ 2>/dev/null || true
      cp *.json $out/output/ 2>/dev/null || true
      cp irs/*.irs $out/irs/ 2>/dev/null || true
    '';
  };
in

{
  options.lucy.easyeffects = {
    enable = lib.mkEnableOption "EasyEffects with presets";
  };

  config = lib.mkIf config.lucy.easyeffects.enable {
    home.packages = [ pkgs.easyeffects ];

    home.file = {
      ".config/easyeffects/output" = {
        source = "${presets}/output";
        recursive = true;
      };
      ".config/easyeffects/irs" = {
        source = "${presets}/irs";
        recursive = true;
      };
    };
  };
}
