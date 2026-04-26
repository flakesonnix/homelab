{ lib, config, pkgs, ... }:

let
  devTools = [ pkgs.gcc pkgs.gdb pkgs.cmake pkgs.ninja pkgs.autoconf pkgs.automake pkgs.libtool pkgs.pkg-config pkgs.ccache pkgs.gnumake pkgs.tree pkgs.dust ];
in
{
  options = with lib; {
    lucy.basePackages = mkOption { type = types.listOf types.package; default = [ ]; };
    lucy.hostPackages = mkOption { type = types.listOf types.package; default = [ ]; };
    lucy.firefox = mkEnableOption "Firefox browser";
    lucy.discord = mkEnableOption "Discord";
    lucy.lmstudio = mkEnableOption "LM Studio";
    lucy.clion = mkEnableOption "CLion IDE";
    lucy.ollama = mkEnableOption "Ollama (CUDA)";
    lucy.swaybg = mkEnableOption "swaybg wallpaper";
    lucy.devBase = mkEnableOption "Dev tools (gcc, gdb, cmake, ninja, etc.)";
    lucy.pwvucontrol = mkEnableOption "PipeWire volume control";
    lucy.scrcpy = mkEnableOption "scrcpy Android screen mirror";
    lucy.nload = mkEnableOption "nload network monitor";
    lucy.iotop = mkEnableOption "iotop I/O monitor";
    lucy.iftop = mkEnableOption "iftop network monitor";
  };

  config = {
    users.users.lucy.packages = config.lucy.basePackages ++ config.lucy.hostPackages
      ++ lib.optionals config.lucy.firefox [ pkgs.firefox ]
      ++ lib.optionals config.lucy.discord [ pkgs.discord ]
      ++ lib.optionals config.lucy.clion [ pkgs.jetbrains.clion ]
      ++ lib.optionals config.lucy.devBase devTools
      ++ lib.optionals config.lucy.pwvucontrol [ pkgs.pwvucontrol ]
      ++ lib.optionals config.lucy.scrcpy [ pkgs.scrcpy ]
      ++ lib.optionals config.lucy.nload [ pkgs.nload ]
      ++ lib.optionals config.lucy.iotop [ pkgs.iotop ]
      ++ lib.optionals config.lucy.iftop [ pkgs.iftop ];

    environment.systemPackages = [ pkgs.nodejs_22 pkgs.gnome-tweaks ]
      ++ lib.optionals config.lucy.swaybg [ pkgs.swaybg ]
      ++ lib.optionals config.lucy.ollama [ pkgs.ollama-cuda ]
      ++ lib.optionals config.lucy.lmstudio [
      (pkgs.appimageTools.wrapType2 {
        pname = "lmstudio";
        version = "latest";
        src = pkgs.fetchurl {
          url = "https://lmstudio.ai/download/latest/linux/x64";
          sha256 = "1hnb0qx154f6s9hgbdmbnv7hb0pzfs1p1wxyjcbbx61aqn8ckd2k";
        };
      })
    ];

    programs.npm.enable = true;
    programs.npm.package = pkgs.nodejs_22;
  };
}
