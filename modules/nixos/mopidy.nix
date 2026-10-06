# Mopidy music server (host module for mireo).
#
# Backends: local files (/data/Music), Jellyfin server, streams/radio.
# Plays to the USB audio interface (Behringer Xenyx 302USB = TI PCM2902,
# USB 08bb:2902) via direct ALSA (GStreamer alsasink) — no VM, no
# PipeWire, no GPU. Control: MPD protocol :6600 (LAN/VPN; M.A.L.P.,
# mpc/ncmpcpp) + Iris web client behind Caddy (music.home.arpa).
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.mopidy;
in {
  config = lib.mkIf cfg.enable {
    # ALSA devices are root:audio by default; mopidy joins audio via the
    # upstream module. Stable device name (no cardN guessing): verify with
    # `aplay -L` on the host, adjust lucy.services.mopidy.alsaDevice.
    users.users.mopidy.extraGroups = ["audio"];
    boot.kernelModules = ["snd-usb-audio"];

    services.mopidy = {
      enable = true;
      extensionPackages = with pkgs; [
        mopidy-mpd
        mopidy-local
        mopidy-jellyfin
        mopidy-somafm
        mopidy-iris
      ];
      settings = {
        mpd.hostname = "10.8.0.1";
        mpd.port = 6600;
        http.hostname = "127.0.0.1";
        http.port = 6680;
        audio.output = "alsasink device=${cfg.alsaDevice}";
        local.media_dir = cfg.musicDirectory;
        jellyfin.hostname = cfg.jellyfinHost;
        jellyfin.username = cfg.jellyfinUser;
        # Password comes from sops (extraConfigFiles below), never the store.
      };
      # Jellyfin credentials: rendered by sops-nix, applied after the main
      # config (later files win). Key must exist in hosts/mireo/secrets.yaml
      # or activation fails — see data/hosts/mireo/services.nix.
      extraConfigFiles = [config.sops.templates."mopidy/jellyfin".path];
    };

    # Mopidy scans local files on demand (`mopidy local scan` / mpc update);
    # the unit exists for manual runs, no timer (library changes rarely).
    systemd.tmpfiles.rules = [
      "d ${cfg.musicDirectory} 0755 lucy users - -"
    ];

    sops.templates."mopidy/jellyfin" = {
      content = ''
        [jellyfin]
        password = ${config.sops.placeholder."mopidy/jellyfin-password"}
      '';
    };

    # MPD protocol on VPN; br0 (LAN) is trusted anyway. No Internet.
    networking.firewall.interfaces.wg0.allowedTCPPorts = [6600];
  };
}
