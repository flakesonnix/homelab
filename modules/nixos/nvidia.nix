{
  lib,
  config,
  pkgs,
  ...
}: {
  options = {
    lucy.nvidia = {
      enable = lib.mkEnableOption "NVIDIA GPU configuration";
      modesetting = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable kernel mode setting";
      };
      legacy580 = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use the 580 legacy branch (Maxwell/Pascal/Volta, z.B. Quadro M1000M). Production >= 590 unterstützt diese nicht mehr.";
      };
      prime = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NVIDIA PRIME offload";
      };
      intelBusId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "PCI:0:2:0";
        description = "PCI bus ID of the Intel iGPU (PRIME offload).";
      };
      nvidiaBusId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "PCI:1:0:0";
        description = "PCI bus ID of the NVIDIA dGPU (PRIME offload).";
      };
    };
  };

  config = lib.mkIf config.lucy.nvidia.enable {
    services.xserver.videoDrivers =
      if config.lucy.nvidia.prime
      then ["modesetting" "nvidia"]
      else ["nvidia"];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.nvidia = {
      powerManagement.enable = true;
      powerManagement.finegrained = config.lucy.nvidia.prime;
      open = false;
      modesetting.enable = config.lucy.nvidia.modesetting;
      nvidiaSettings = true;
      package =
        if config.lucy.nvidia.legacy580
        then config.boot.kernelPackages.nvidiaPackages.legacy_580
        else config.boot.kernelPackages.nvidiaPackages.production;
      prime = lib.mkIf (config.lucy.nvidia.prime && config.lucy.nvidia.intelBusId != null && config.lucy.nvidia.nvidiaBusId != null) {
        inherit (config.lucy.nvidia) intelBusId nvidiaBusId;
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };

    boot.blacklistedKernelModules = ["nouveau"];
    boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

    boot.kernelParams = [
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
      "mem_sleep_default=s2idle"
    ];

    services.logind = {
      settings = {
        Login = {
          HandlePowerKey = lib.mkDefault "poweroff";
          HandleSuspendKey = lib.mkDefault "suspend";
          HandleLidSwitch = lib.mkDefault "suspend";
          HandleLidSwitchExternalPower = lib.mkDefault "suspend";
          HandleLidSwitchDocked = lib.mkDefault "ignore";
        };
      };
    };

    systemd.services.nvidia-loader = let
      scripts = import ../../lib/system-scripts.nix pkgs;
    in {
      description = "Lazy-load NVIDIA kernel modules";
      wantedBy = ["graphical.target"];
      after = ["graphical.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${scripts.mkNvidiaLoader}/bin/nvidia-loader";
      };
    };
  };
}
