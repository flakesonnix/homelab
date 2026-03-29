{ lib, config, ... }:

{
  options.p50 = {
    nixSettings = lib.mkEnableOption "Nix settings for p50";
  };

  config = lib.mkIf config.p50.nixSettings {
    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
      };
    };
  };
}
