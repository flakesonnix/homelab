{ config, lib, pkgs, ... }:

{
  options.lucy.openclaude = {
    enable = lib.mkEnableOption "OpenClaude CLI";
  };

  config = lib.mkIf config.lucy.openclaude.enable {
    home.packages = [ pkgs.nodejs ];

    home.activation.installOpenclaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.nodejs}/bin/npm install -g @gitlawb/openclaude 2>/dev/null || true
    '';
  };
}
