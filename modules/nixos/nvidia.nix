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
    };
  };

  config = lib.mkIf config.lucy.nvidia.enable {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      powerManagement.enable = true;
      powerManagement.finegrained.frequencyManagement = "on";
      modesetting.enable = config.lucy.nvidia.modesetting;
      nvidiaSettings = true;
    };
  };
}
