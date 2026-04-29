{
  moduleFlags = {
    lucy.alacritty.enable = true;
    lucy.easyeffects.enable = true;
    lucy.firefoxUi.enable = true;
    lucy.fuzzel.enable = true;
    lucy.gnomeTheme.enable = true;
    lucy.niri.enable = true;
    lucy.stylix.enable = true;
    lucy.thunderbirdUi.enable = true;
    lucy.vesktop.enable = true;
    lucy.waybar.enable = true;
    lucy.zathura.enable = true;
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
