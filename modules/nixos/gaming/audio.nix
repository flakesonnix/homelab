{
  config,
  lib,
  ...
}: let
  cfg = config.lucy.gaming;
in {
  config = lib.mkIf cfg.enable {
    services.pipewire.lowLatency = lib.mkIf cfg.lowLatency.enable {
      enable = true;
      inherit (cfg.lowLatency) quantum;
      inherit (cfg.lowLatency) rate;
    };
  };
}
