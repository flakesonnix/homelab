{
  lib,
  nixGaming,
  ...
}: {
  imports = [
    nixGaming.nixosModules.pipewireLowLatency
    nixGaming.nixosModules.platformOptimizations
  ];

  options.lucy.gaming = {
    enable = lib.mkEnableOption "gaming optimizations";

    steam.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Steam and supporting desktop integration.";
    };

    gamemode.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Feral GameMode support.";
    };

    gamescope = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Gamescope.";
      };

      capSysNice = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow Gamescope to raise thread priority for lower-latency scheduling.";
      };
    };

    mangohud.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable MangoHud performance overlay support.";
    };

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

    performance = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable performance-biased tuning for dedicated gaming hosts.";
      };

      cpuFreqGovernor = lib.mkOption {
        type = lib.types.str;
        default = "performance";
        description = "CPU frequency governor to apply when performance tuning is enabled.";
      };

      disablePowerProfilesDaemon = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Disable power-profiles-daemon when an explicit governor is managed declaratively.";
      };
    };
  };
}
