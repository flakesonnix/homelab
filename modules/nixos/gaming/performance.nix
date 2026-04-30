{
  config,
  lib,
  ...
}: let
  cfg = config.lucy.gaming;
in {
  config = lib.mkIf cfg.enable {
    powerManagement.cpuFreqGovernor = lib.mkIf cfg.performance.enable (lib.mkDefault cfg.performance.cpuFreqGovernor);

    services.power-profiles-daemon.enable = lib.mkIf cfg.performance.disablePowerProfilesDaemon (lib.mkForce false);
  };
}
