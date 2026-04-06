{ lib, config, ... }:

let
  cfg = config.hq.audio;
in

{
  options.hq.audio = {
    streamTo = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Hostname or IP of the remote audio sink to stream to";
    };
  };

  config = lib.mkIf (cfg.streamTo != "") {
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      wireplumber.enable = true;
      extraConfig = {
        client = {
          "context.properties" = {
            "remote.#" = {
              "remote.tcp" = cfg.streamTo;
              "connect.autoconnect" = true;
            };
          };
        };
      };
    };
  };
}
