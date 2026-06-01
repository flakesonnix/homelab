pkgs: {
  # Lazy-load NVIDIA kernel modules after graphical.target.
  # Skips if modules aren't built for the currently running kernel (safe after
  # nixos-rebuild switch without reboot).
  mkNvidiaLoader = pkgs.writeShellApplication {
    name = "nvidia-loader";
    runtimeInputs = [pkgs.kmod];
    text = ''
      if ! modinfo -k "$(uname -r)" nvidia >/dev/null 2>&1; then
        exit 0
      fi
      exec modprobe nvidia nvidia_modeset nvidia_uvm nvidia_drm
    '';
  };

  # Power-cycle a USB device by vendor:product ID via uhubctl.
  # Usage: pipebert-reload-usb VID PID
  mkUsbReload = pkgs.writeShellApplication {
    name = "pipebert-reload-usb";
    runtimeInputs = with pkgs; [coreutils gawk uhubctl usbutils];
    text = ''
      if [[ $# != 2 ]]; then
        printf 'Usage: %s VID PID\n' "$0" >&2
        exit 2
      fi
      vid=$1
      pid=$2
      lsusb_device=$(lsusb -d "$vid:$pid")
      if [[ -z $lsusb_device ]]; then
        printf 'Device %s:%s not found\n' "$vid:$pid" >&2
        exit 2
      fi
      usb_bus=$(printf '%s\n' "$lsusb_device" | awk '{ print $2; }' | cut -c 1-3)
      usb_device=$(printf '%s\n' "$lsusb_device" | awk '{ print $4; }' | cut -c 1-3)
      usb_devpath=$(udevadm info -q property --property=DEVPATH "/dev/bus/usb/$usb_bus/$usb_device" | awk -F = '{ print $2; }')
      usb_location=$(printf '%s\n' "$usb_devpath" | awk -F / '{ print $NF; }')
      hub_location=$(printf '%s\n' "$usb_location" | awk -F . '{ print $1; }')
      hub_port=$(printf '%s\n' "$usb_location" | awk -F . '{ print $2; }')
      uhubctl --force --location "$hub_location" --ports "$hub_port" --action cycle
    '';
  };
}
