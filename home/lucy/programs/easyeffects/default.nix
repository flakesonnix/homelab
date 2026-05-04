{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
  css = frameworkLib.render.css;
in {
  config = lib.mkIf config.programs.easyeffects.enable {
    home.packages = [pkgs.easyeffects];

    xdg.configFile."easyeffects/config.json".text = builtins.toJSON {
      input = {
        plugins = [
          {name = "loudness"; enabled = true;}
          {name = "bass_enhancer"; enabled = true;}
          {name = "equalizer"; enabled = true;}
        ];
      };
      output = {
        plugins = [
          {name = "reverb"; enabled = false;}
          {name = "bass_enhancer"; enabled = true;}
        ];
      };
    };
  };
}
