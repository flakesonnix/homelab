{pkgs}: {
  moduleFlags = {
    lucy.base.enable = true;
    lucy.nvidia.enable = true;
    lucy.gnome.enable = false;
    lucy.gnomeExtensions.enable = false;
    lucy.gaming.enable = true;
    lucy.gaming.steam.enable = true;
    lucy.gaming.gamemode.enable = true;
    lucy.gaming.gamescope.enable = true;
    lucy.gaming.mangohud.enable = true;
    lucy.fonts.inter = true;
    lucy.niri.enable = true;
    lucy.waybar.installFonts = true;
  };

  packageToggles = [
    "firefox"
    "discord"
    "clion"
    "ollama"
    "lmstudio"
    "swaybg"
    "devBase"
    "pwvucontrol"
    "scrcpy"
    "nload"
    "iotop"
    "iftop"
  ];

  basePackages = with pkgs; [
    alacritty
    zathura
    fzf
    bat
    vesktop
    vlc
    p7zip
    thunderbird
    deskflow
    keepassxc
    nodejs_22
    ausweisapp
    kdePackages.kdenlive
    ani-cli
    scdl
  ];

  settings = {
    networking.hostName = "omen";
    networking.networkmanager.enable = true;

    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.availableKernelModules = ["r8169"];
    boot.kernelParams = [
      "tpm.disable=1"
      "nvme_core.default_ps_max_latency_us=0"
      "console=tty1"
    ];

    nix.settings.require-sigs = false;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nix.optimise.automatic = true;

    security.run0-sudo-shim.enable = true;
    services.openssh.settings.PermitRootLogin = "prohibit-password";
    system.stateVersion = "25.11";
  };
}
