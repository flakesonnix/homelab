{ lib, config, ... }:

{
  options.lucy.openclaude = {
    enable = lib.mkEnableOption "OpenClaude CLI tool";
  };

  config = lib.mkIf config.lucy.openclaude.enable {
    assertions = [
      {
        assertion = false;
        message = "openclaude is broken: npm packaging issues - requires network access during build";
      }
    ];
  };
}
