{lib, ...}: let
  disabledGettys = ["ttyS0" "ttyS1" "ttyS2" "ttyS3"];
in {
  systemd.services =
    lib.genAttrs (map (tty: "serial-getty@${tty}") disabledGettys)
    (_: {
      enable = false;
    })
    // {
      nvidia-resume = {
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
              systemctl restart gdm.service 2>/dev/null || true
            ''
          ];
        };
      };
    };

  services.thermald.enable = true;

  powerManagement.enable = true;
}
