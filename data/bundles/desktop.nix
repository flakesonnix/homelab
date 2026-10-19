{
  meta = {
    description = "Desktop GUI apps, stylix, and flatpak desktop integrations";
    targets = ["home"];
  };

  programs = {
    alacritty.enable = true;
    # GNOME bringt eigene Notifications/Shell: dunst/eww/fuzzel/rofi/niri
    # bleiben als Module erhalten, sind aber deaktiviert.
    dunst.enable = false;
    eww.enable = false;
    firefox.enable = true;
    fuzzel.enable = false;
    gnomeTheme.enable = true;
    gnomeShell.enable = true;
    niri.enable = false;
    rofi.enable = false;
    starship.enable = true;
    thunderbird.enable = true;
    vesktop.enable = true;
    virtManager.enable = true;
    waybar.enable = false;
    zathura.enable = true;
  };

  settings.stylix = {
    enable = true;
    targets.alacritty.enable = false;
  };

  packageToggles = [
    "geist-mono"
    "nautilus"
  ];

  services.flatpak = {
    enable = true;
    packages = [
      "com.teamspeak.TeamSpeak"
    ];
  };
}
