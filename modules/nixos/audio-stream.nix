{
  lib,
  config,
  ...
}: let
  cfg = config.hq.audio;
in {
  options.hq.audio = {
    streamTo = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Hostname or IP of the remote PulseAudio TCP receiver (port 4713)";
    };
  };

  config = lib.mkIf (cfg.streamTo != "") {
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      wireplumber.enable = true;
      extraConfig = {
        pipewire-pulse."30-tunnel-sink" = {
          "pulse.cmd" = [
            {
              cmd = "load-module";
              args = "module-tunnel-sink server=${cfg.streamTo}:4713 sink_name=remote-${cfg.streamTo} sink_properties=device.description=Remote\\ Audio\\ (${cfg.streamTo})";
            }
          ];
        };
      };
    };
  };
}
