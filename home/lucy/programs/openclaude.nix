{ config, lib, pkgs, ... }:

{
  options.lucy.openclaude = {
    enable = lib.mkEnableOption "OpenClaude CLI";
  };

  config = lib.mkIf config.lucy.openclaude.enable {
    home.packages = [
      (pkgs.writeScriptBin "openclaude" ''
        #!${pkgs.bash}/bin/bash
        export PATH="${pkgs.nodejs_22}/bin:$PATH"
        exec -a openclaude ${pkgs.nodejs_22}/bin/npm exec -g @gitlawb/openclaude -- "$@"
      '')
    ];
  };
}
