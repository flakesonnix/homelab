{pkgs}: let
  devTools = with pkgs; [
    gcc
    gdb
    cmake
    ninja
    autoconf
    automake
    libtool
    pkg-config
    ccache
    gnumake
    tree
    dust
  ];
in {
  firefox = {
    description = "Firefox browser";
    targets = ["user"];
    packages.user = [pkgs.firefox];
    tags = ["desktop" "browser"];
  };

  discord = {
    description = "Discord";
    targets = ["user"];
    packages.user = [pkgs.discord];
    tags = ["desktop" "chat"];
  };

  lmstudio = {
    description = "LM Studio";
    targets = ["system"];
    packages.system = [
      (pkgs.appimageTools.wrapType2 {
        pname = "lmstudio";
        version = "latest";
        src = pkgs.fetchurl {
          url = "https://lmstudio.ai/download/latest/linux/x64";
          sha256 = "1hnb0qx154f6s9hgbdmbnv7hb0pzfs1p1wxyjcbbx61aqn8ckd2k";
        };
      })
    ];
    tags = ["desktop" "llm"];
  };

  clion = {
    description = "CLion IDE";
    targets = ["user"];
    packages.user = [pkgs.jetbrains.clion];
    tags = ["dev" "jetbrains"];
  };

  ollama = {
    description = "Ollama (CUDA)";
    targets = ["system"];
    packages.system = [pkgs.ollama-cuda];
    tags = ["llm" "gpu"];
  };

  swaybg = {
    description = "swaybg wallpaper";
    targets = ["system"];
    packages.system = [pkgs.swaybg];
    tags = ["desktop" "wayland"];
  };

  devBase = {
    description = "Dev tools (gcc, gdb, cmake, ninja, etc.)";
    targets = ["user"];
    packages.user = devTools;
    tags = ["dev"];
  };

  pwvucontrol = {
    description = "PipeWire volume control";
    targets = ["user"];
    packages.user = [pkgs.pwvucontrol];
    tags = ["desktop" "audio"];
  };

  scrcpy = {
    description = "scrcpy Android screen mirror";
    targets = ["user"];
    packages.user = [pkgs.scrcpy];
    tags = ["desktop" "android"];
  };

  nload = {
    description = "nload network monitor";
    targets = ["user"];
    packages.user = [pkgs.nload];
    tags = ["cli" "network"];
  };

  iotop = {
    description = "iotop I/O monitor";
    targets = ["user"];
    packages.user = [pkgs.iotop];
    tags = ["cli" "monitoring"];
  };

  iftop = {
    description = "iftop network monitor";
    targets = ["user"];
    packages.user = [pkgs.iftop];
    tags = ["cli" "monitoring"];
  };
}
