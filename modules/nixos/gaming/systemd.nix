{
  config,
  lib,
  ...
}: let
  cfg = config.lucy.gaming;
in {
  config = lib.mkIf cfg.enable {
    systemd.slices.gaming = {
      sliceConfig = {
        CPUWeight = lib.mkIf cfg.performance.enable 20;
        IOWeight = lib.mkIf cfg.performance.enable 100;
        MemoryPressureWatch = "auto";
        MemoryPressureLimitSec = "30s";
      };
    };
  };
}
