{pkgs}: {
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

  fontPackages = with pkgs; [
    hack-font
  ];
}
