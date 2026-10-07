{
  meta = {
    description = "Desktop GUI apps, stylix, and flatpak desktop integrations";
    targets = ["home"];
  };

  programs = {
    alacritty.enable = true;
    dunst.enable = true;
    eww.enable = true;
    firefox.enable = true;
    fuzzel.enable = true;
    gnomeTheme.enable = true;
    niri.enable = true;
    rofi.enable = true;
    starship.enable = true;
    thunderbird.enable = true;
    vesktop.enable = true;
    virtManager.enable = true;
    # eww ist die Desktop-Shell (topbar + sidebar); waybar bleibt als
    # Modul erhalten, ist aber deaktiviert (kein Parallelbetrieb).
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
