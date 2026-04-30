{
  config,
  lib,
  ...
}: let
  cfg = config.lucy.nvidia.resumeWorkaround;
in {
  options.lucy.nvidia.resumeWorkaround = {
    enable = lib.mkEnableOption "NVIDIA suspend/resume rebind workaround";

    restartUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Units to restart after rebinding NVIDIA devices on resume.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nvidia-resume = {
      description = lib.mkForce "Reinitialize NVIDIA driver after resume";
      after = ["suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target"];
      wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.mkForce [
          "/bin/sh"
          "-c"
          ''
            #!/bin/sh
            if [ -d /sys/bus/pci/drivers/nvidia ]; then
              for dev in /sys/bus/pci/drivers/nvidia/*; do
                if [ -e "$dev" ]; then
                  vendor=$(cat "$dev/vendor" 2>/dev/null)
                  if [ "$vendor" = "0x10de" ]; then
                    devname=$(basename "$dev")
                    echo "$devname" > /sys/bus/pci/drivers/nvidia/unbind 2>/dev/null
                    echo "$devname" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null
                  fi
                fi
              done
            fi

            ${lib.concatStringsSep "\n" (map (unit: "systemctl restart ${unit} 2>/dev/null || true") cfg.restartUnits)}
          ''
        ];
      };
    };
  };
}
