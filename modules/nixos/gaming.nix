{
  lib,
  config,
  pkgs,
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
    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam and supporting desktop integration.";
      };
    };
    gamemode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Feral GameMode support.";
      };
    };
    gamescope = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Gamescope.";
      };
    };
    mangohud = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable MangoHud performance overlay support.";
      };
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
  };

  config = lib.mkIf cfg.enable {
    hardware.steam-hardware.enable = cfg.steam.enable;
    programs.steam.enable = cfg.steam.enable;
    programs.steam.platformOptimizations.enable = cfg.platformOptimizations;
    programs.gamemode.enable = cfg.gamemode.enable;
    programs.gamescope.enable = cfg.gamescope.enable;
    environment.systemPackages = lib.optionals cfg.mangohud.enable [pkgs.mangohud];

    services.pipewire.lowLatency = lib.mkIf cfg.lowLatency.enable {
      enable = true;
      inherit (cfg.lowLatency) quantum;
      inherit (cfg.lowLatency) rate;
    };
  };
}
