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
      prime = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NVIDIA PRIME offload";
      };
    };
  };

  config = lib.mkIf config.lucy.nvidia.enable {
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {
      powerManagement.enable = true;
      powerManagement.finegrained = config.lucy.nvidia.prime;
      open = false;
      modesetting.enable = config.lucy.nvidia.modesetting;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };

    boot.initrd.kernelModules = []; # Lazy-load, not in initrd

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
          HandlePowerKey = "poweroff";
          HandleSuspendKey = "suspend";
          HandleLidSwitch = "suspend";
          HandleLidSwitchExternalPower = "suspend";
          HandleLidSwitchDocked = "ignore";
        };
      };
    };

    systemd.services.nvidia-loader = {
      description = "Lazy-load NVIDIA kernel modules";
      wantedBy = ["graphical.target"];
      after = ["graphical.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.kmod}/bin/modprobe nvidia nvidia_modeset nvidia_uvm nvidia_drm";
      };
    };
  };
}
