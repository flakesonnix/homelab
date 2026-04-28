{
  lib,
  config,
  pkgs,
  ...
}: let
  projectLib = import ../../lib;
  devTools = [pkgs.gcc pkgs.gdb pkgs.cmake pkgs.ninja pkgs.autoconf pkgs.automake pkgs.libtool pkgs.pkg-config pkgs.ccache pkgs.gnumake pkgs.tree pkgs.dust];
  packageOptions = {
    firefox = {
      description = "Firefox browser";
      userPackages = [pkgs.firefox];
    };
    discord = {
      description = "Discord";
      userPackages = [pkgs.discord];
    };
    lmstudio = {
      description = "LM Studio";
      systemPackages = [
        (pkgs.appimageTools.wrapType2 {
          pname = "lmstudio";
          version = "latest";
          src = pkgs.fetchurl {
            url = "https://lmstudio.ai/download/latest/linux/x64";
            sha256 = "1hnb0qx154f6s9hgbdmbnv7hb0pzfs1p1wxyjcbbx61aqn8ckd2k";
          };
        })
      ];
    };
    clion = {
      description = "CLion IDE";
      userPackages = [pkgs.jetbrains.clion];
    };
    ollama = {
      description = "Ollama (CUDA)";
      systemPackages = [pkgs.ollama-cuda];
    };
    swaybg = {
      description = "swaybg wallpaper";
      systemPackages = [pkgs.swaybg];
    };
    devBase = {
      description = "Dev tools (gcc, gdb, cmake, ninja, etc.)";
      userPackages = devTools;
    };
    pwvucontrol = {
      description = "PipeWire volume control";
      userPackages = [pkgs.pwvucontrol];
    };
    scrcpy = {
      description = "scrcpy Android screen mirror";
      userPackages = [pkgs.scrcpy];
    };
    nload = {
      description = "nload network monitor";
      userPackages = [pkgs.nload];
    };
    iotop = {
      description = "iotop I/O monitor";
      userPackages = [pkgs.iotop];
    };
    iftop = {
      description = "iftop network monitor";
      userPackages = [pkgs.iftop];
    };
  };
in {
  options = with lib; {
    lucy =
      {
        basePackages = mkOption {
          type = types.listOf types.package;
          default = [];
        };
        hostPackages = mkOption {
          type = types.listOf types.package;
          default = [];
        };
      }
      // projectLib.mkPackageOptions lib packageOptions;
  };

  config = {
    users.users.lucy.packages =
      config.lucy.basePackages
      ++ config.lucy.hostPackages
      ++ projectLib.getEnabledPackagesBy lib config.lucy packageOptions (value: value.userPackages or []);

    environment.systemPackages =
      [pkgs.nodejs_22 pkgs.gnome-tweaks]
      ++ projectLib.getEnabledPackagesBy lib config.lucy packageOptions (value: value.systemPackages or []);

    programs.npm.enable = true;
    programs.npm.package = pkgs.nodejs_22;
  };
}
