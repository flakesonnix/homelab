{ lib, config, ... }:

{
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
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      powerManagement.enable = true;
      powerManagement.finegrained.frequencyManagement = "on";
      modesetting.enable = config.lucy.nvidia.modesetting;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };

    boot.kernelParams = [
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
      "mem_sleep_default=s2idle"
    ];

    services.logind = {
      suspendThenHibernate = false;
      powerKey = "poweroff";
      suspendKey = "suspend";
      lidSwitch = "suspend";
      lidSwitchExternalPower = "suspend";
      lidSwitchDocked = "ignore";
    };

    systemd.sleep.extraConfig = ''
      # Enable deep sleep for better NVIDIA resume
      SuspendState=mem freeze freeze
    '';
  };
}
