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

      enableIrqbalance = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable irqbalance when performance tuning is enabled.";
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

    sysctl = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply custom sysctl tuning on top of platformOptimizations.";
      };

      scheduler = {
        migrationCostNs = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 5000000;
          description = "kernel.sched_migration_cost_ns. Higher = less migration between cores.";
        };

        latencyNs = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "kernel.sched_latency_ns. null = keep platformOptimizations default.";
        };
      };

      memory = {
        maxMapCount = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 524288;
          description = "vm.max_map_count. Required by some games (e.g. Zen4 Ryzens, some Wine titles).";
        };

        dirtyRatio = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "vm.dirty_ratio. null = keep default.";
        };
      };

      fs = {
        inotifyMaxWatches = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "fs.inotify.max_user_watches. null = keep platformOptimizations default.";
        };
      };

      network = {
        lowLatency = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Apply network buffer tuning for competitive gaming.";
        };

        rmemMax = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 16777216;
          description = "net.core.rmem_max.";
        };

        wmemMax = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 16777216;
          description = "net.core.wmem_max.";
        };

        tcpLowLatency = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 1;
          description = "net.ipv4.tcp_low_latency.";
        };
      };
    };
  };
}
