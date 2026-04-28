{
  lib,
  config,
  nixGaming,
  ...
}: let
  cfg = config.lucy.gaming;
in {
  imports = [
    nixGaming.nixosModules.pipewireLowLatency
    nixGaming.nixosModules.platformOptimizations
  ];

  options.lucy.gaming = {
    enable = lib.mkEnableOption "gaming optimizations";
    platformOptimizations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SteamOS-style kernel sysctl tweaks.";
    };
    lowLatency = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable low-latency PipeWire tuning.";
      };
      quantum = lib.mkOption {
        type = lib.types.int;
        default = 64;
        description = "Minimum PipeWire quantum.";
      };
      rate = lib.mkOption {
        type = lib.types.int;
        default = 48000;
        description = "Nominal PipeWire sample rate.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam.platformOptimizations.enable = cfg.platformOptimizations;
    services.pipewire.lowLatency = lib.mkIf cfg.lowLatency.enable {
      enable = true;
      inherit (cfg.lowLatency) quantum;
      inherit (cfg.lowLatency) rate;
    };
  };
}
