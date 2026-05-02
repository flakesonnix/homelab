{
  meta = {
    description = "Desktop GUI apps, stylix, and flatpak desktop integrations";
    targets = ["home"];
  };

  programs = {
    alacritty.enable = true;
    easyeffects.enable = true;
    firefox.enable = true;
    fuzzel.enable = true;
    gnomeTheme.enable = true;
    niri.enable = true;
    thunderbird.enable = true;
    vesktop.enable = true;
    waybar.enable = true;
    zathura.enable = true;
  };

  settings.stylix.enable = true;

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
