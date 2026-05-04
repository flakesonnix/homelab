{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.mpv.enable {
    home.packages = [pkgs.mpv];

    xdg.configFile."mpv/mpv.conf".text = ''
      profile=gpu-hq
      vo=gpu-next
      ao=pipewire
      hwdec=auto
      fullscreen=yes
      keepaspect=yes
      autofit-larger=100%x100%
      geometry=50%:50%
      osd-level=1
      osd-duration=2000
      osd-font=Inter
      osd-font-size=16
      sub-font=Inter
      sub-font-size=16
      sub-color=#FFFFFF
      sub-shadow-color=#000000
      sub-shadow-offset=1
      screenshot-format=png
      screenshot-template=~/Pictures/Screenshots/mpv_%F_%p
      screenshot-directory=~~/Pictures/Screenshots/
      save-position-on-quit=yes
      resume-playback=yes
      history-file=~~/.local/state/mpv/history.mpv
    '';

    xdg.configFile."mpv/input.conf".text = ''
      <right> seek 5
      <left> seek -5
      <up> seek 60
      <down> seek -60
      Space pause
      f cycle fullscreen
      ESC quit
      p quit
      s screenshot
      < shift+right> seek 600
      < shift+left> seek -600
      [ multiply speed 0.5
      ] multiply speed 2.0
      { multiply speed 0.5
      } multiply speed 2.0
      BS set speed 1.0
      m cycle mute
      9 add volume -2
      0 add volume 2
      / add audio-delay -0.1
      * add audio-delay 0.1
    '';
  };
}
