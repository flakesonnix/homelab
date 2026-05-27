{
  config,
  lib,
  pkgs,
  ...
}: {
  config = {
    home.packages = [pkgs.easyeffects];

    xdg.configFile."easyeffects/config.json".text = builtins.toJSON {
      input = {
        plugins = [
          {
            name = "loudness";
            enabled = true;
          }
          {
            name = "bass_enhancer";
            enabled = true;
          }
          {
            name = "equalizer";
            enabled = true;
          }
        ];
      };
      output = {
        plugins = [
          {
            name = "reverb";
            enabled = false;
          }
          {
            name = "bass_enhancer";
            enabled = true;
          }
        ];
      };
    };
  };
}
