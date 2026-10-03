# Kodi headless music box (guest module for the kodi microVM on mireo).
#
# Plays YouTube / SoundCloud / Jellyfin to a USB audio interface
# (Behringer Xenyx 302USB = TI PCM2902, USB 08bb:2902, passed through
# from the mireo host via microvm.devices, see kodi-microvm.nix).
#
# Control (no TV needed):
# - Kodi web UI (Chorus): http://kodi.home.arpa (Caddy on mireo -> :8080)
# - Firefox "Play to Kodi" addon (YouTube + SoundCloud), host kodi.home.arpa:8080
# - Android Kore / Yatse (Zeroconf auto-discovery via Avahi, else 10.8.0.31)
#
# One-time runtime setup (kept out of the store on purpose):
# - YouTube addon: personal API key/Client-ID (Google Cloud Console),
#   addon settings -> API. Without it playback is throttled/broken.
# - JellyCon: server is pre-seeded (see jellyfinHost), just log in with
#   the Jellyfin user via the web UI.
# - SoundCloud: Kodi repo -> Music Add-ons -> SoundCloud (no key needed),
#   or any SoundCloud URL via the SendToKodi addon (yt-dlp, audio-only).
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services."kodi-box";
  kodiBundle = pkgs.kodi.withPackages (ps: [
    ps.youtube
    ps.jellyfin
    ps.jellycon
    ps.sendtokodi
  ]);

  seedGuiSettings = pkgs.writeText "kodi-guisettings.xml" ''
    <settings version="2">
      <!-- Seeded once (tmpfiles C); user changes persist afterwards. -->
      <setting id="audiooutput.audiodevice">ALSA:hw:CARD=CODEC,DEV=0</setting>
      <setting id="audiooutput.channels">2</setting>
      <setting id="services.webserver">true</setting>
      <setting id="services.webserverport">${toString cfg.httpPort}</setting>
      <setting id="services.esenabled">true</setting>
      <setting id="services.esport">${toString cfg.eventPort}</setting>
      <setting id="services.esallinterfaces">true</setting>
      <setting id="services.zeroconf">true</setting>
      <setting id="services.upnpserver">true</setting>
      <setting id="services.upnprenderer">true</setting>
    </settings>
  '';

  # File-mode access to the Jellyfin library (virtiofs /media, no login).
  seedSources = pkgs.writeText "kodi-sources.xml" ''
    <sources>
      <music>
        <default pathversion="1"></default>
        <source>
          <name>Jellyfin Media</name>
          <path pathversion="1">/media/</path>
          <allowsharing>true</allowsharing>
        </source>
      </music>
    </sources>
  '';

  # JellyCon server pointer (login itself stays a runtime step).
  seedJellycon = pkgs.writeText "jellycon-settings.xml" ''
    <settings version="2">
      <setting id="ipaddress">${cfg.jellyfinHost}</setting>
      <setting id="port">8096</setting>
      <setting id="protocol">0</setting>
      <setting id="server_address">${cfg.jellyfinHost}:8096</setting>
    </settings>
  '';
in {
  config = lib.mkIf cfg.enable {
    users.users.kodi = {
      isSystemUser = true;
      group = "kodi";
      home = cfg.dataDir;
      createHome = true;
      extraGroups = ["audio"];
    };
    users.groups.kodi = {};

    # Kodi braucht trotz headless-Betrieb (Steuerung per Web/API) beim
    # Start einen X11-GL-Kontext (--windowing kennt nur x11, kein
    # --headless). Xvfb stellt das Display, Mesa/llvmpipe das Software-GL
    # (keine GPU in der VM). Ohne hardware.graphics fehlt /run/opengl-driver
    # und Kodi stirbt mit SIGABRT vor jeder Log-Ausgabe (seen 2026-10-03).
    hardware.graphics.enable = true;

    # USB mixer as default ALSA card (host must NOT grab it: exclusive
    # passthrough, mireo runs no audio stack).
    boot.kernelModules = ["snd-usb-audio"];
    boot.extraModprobeConfig = ''
      options snd-usb-audio index=0
    '';
    environment.etc."asound.conf".text = ''
      defaults.pcm.card CODEC
      defaults.ctl.card CODEC
    '';

    networking.firewall.allowedTCPPorts = [cfg.httpPort cfg.jsonRpcPort];
    networking.firewall.allowedUDPPorts = [cfg.eventPort 5353];

    # Zeroconf announcement for Kore/Yatse auto-discovery.
    services.avahi = {
      enable = true;
      publish.enable = true;
      publish.userServices = true;
    };

    environment.systemPackages = [kodiBundle pkgs.yt-dlp pkgs.alsa-utils];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 kodi kodi - -"
      "d ${cfg.dataDir}/.kodi/userdata/addon_data/plugin.video.jellycon 0750 kodi kodi - -"
      "C ${cfg.dataDir}/.kodi/userdata/guisettings.xml 0640 kodi kodi - ${seedGuiSettings}"
      "C ${cfg.dataDir}/.kodi/userdata/sources.xml 0640 kodi kodi - ${seedSources}"
      "C ${cfg.dataDir}/.kodi/userdata/addon_data/plugin.video.jellycon/settings.xml 0640 kodi kodi - ${seedJellycon}"
    ];

    # Full Kodi on a virtual display (Xvfb): the proven headless pattern,
    # driven via web UI / JSON-RPC / EventServer. Audio goes direct ALSA
    # to the USB mixer, no PipeWire/PulseAudio daemon involved.
    systemd.services.kodi = {
      description = "Kodi headless music box";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        User = "kodi";
        Group = "kodi";
        Restart = "always";
        RestartSec = "5s";
      };
      script = ''
        exec ${pkgs.xvfb-run}/bin/xvfb-run -a -s "-screen 0 1280x720x24" ${kodiBundle}/bin/kodi
      '';
    };
  };
}
