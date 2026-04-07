{ lib, config, pkgs, ... }:

let
  cfg = config.hq.audio;
in

{
  options.hq.audio = {
    sink = lib.mkEnableOption "HQ audio sink (make this machine a network audio output)";
    sinkName = lib.mkOption {
      type = lib.types.str;
      default = "Pulsebert";
      description = "Name of the audio sink for network discovery";
    };
    airplay = lib.mkEnableOption "HQ AirPlay server (for Apple devices)";
    airplayName = lib.mkOption {
      type = lib.types.str;
      default = "Glotzbert";
      description = "Name of the AirPlay service";
    };
    backend = lib.mkOption {
      type = lib.types.enum [ "pulseaudio" "pipewire" ];
      default = "pipewire";
      description = "Audio backend to use";
    };
  };

  config = {
    services.avahi = lib.mkIf cfg.sink {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    networking.firewall = lib.mkIf cfg.sink {
      enable = true;
      allowedUDPPorts = [ 5353 ];
      allowedTCPPorts = [ 5353 5000 6000 ];
    };

    hardware.pulseaudio = lib.mkIf (cfg.sink && cfg.backend == "pulseaudio") {
      enable = true;
      extraConfig = ''
        # Enable network access
        load-module module-native-protocol-tcp auth-anonymous=1
        load-module module-udev-detect
        # Set sink name for discovery
        set-default-sink ${cfg.sinkName}
      '';
    };

    services.pipewire = lib.mkIf (cfg.sink && cfg.backend == "pipewire") {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      alsa.enable = true;
      wireplumber.enable = true;
      extraConfig = {
        pipewire = {
          "context.extra-modules" = [
            "libpipewire-module-rt"
            "libpipewire-module-profiler"
            "libpipewire-module-metadata"
            "libpipewire-module-spa-device"
            "libpipewire-module-spa-node-factory"
            "libpipewire-module-client-node"
            "libpipewire-module-link-factory"
            "libpipewire-module-session-manager"
          ];
          "context.properties" = {
            "network.tcp.globals" = "*";
          };
        };
      };
    };

    services.shairport-sync = lib.mkIf cfg.airplay {
      enable = true;
      settings.name = cfg.airplayName;
    };

    environment.systemPackages = with pkgs; lib.mkMerge [
      (lib.mkIf (cfg.sink && cfg.backend == "pulseaudio") [ avahi ])
      (lib.mkIf (cfg.sink && cfg.backend == "pipewire") [ avahi ])
      (lib.mkIf cfg.airplay [ shairport-sync ])
    ];
  };
}
