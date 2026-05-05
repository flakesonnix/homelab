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
    waybar.enable = false;
    zathura.enable = true;
  };

  settings.stylix = {
    enable = true;
    targets.alacritty.enable = false;
  };

  packageToggles = [
    "jetbrains-mono"
    "nautilus"
  ];

  services.flatpak = {
    enable = true;
    packages = [
      "com.teamspeak.TeamSpeak"
    ];
  };

  xdg.desktopEntries.lmstudio = {
    name = "LM Studio";
    genericName = "LLM Runner";
    comment = "Run LLMs locally";
    exec = "lmstudio --no-sandbox %U";
    icon = "lmstudio";
    terminal = false;
    categories = ["Development"];
    mimeType = ["x-scheme-handler/chat"];
  };
}
