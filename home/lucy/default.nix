{ osConfig, pkgs, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/alacritty
    ./programs/packages.nix
    ./programs/easyeffects
    ./programs/htop.nix
    ./programs/btop.nix
    ./programs/bat
    ./programs/fzf
    ./programs/firefox.nix
    ./programs/gnome-theme.nix
    ./programs/thunderbird.nix
    ./programs/vesktop.nix
    ./programs/zathura
    ../../modules/home/stylix.nix
    ../../modules/home/ssh.nix
    ../../modules/home/waybar.nix
    ../../modules/home/opencode.nix
    ../../modules/home/niri.nix
  ];

  lucy.shell.enable = true;
  lucy.git.enable = true;
  lucy.editor.enable = true;
  lucy.alacritty.enable = true;
  lucy.easyeffects.enable = true;
  lucy.htop.enable = true;
  lucy.btop.enable = true;
  lucy.bat.enable = true;
  lucy.fzf.enable = true;
  lucy.firefoxUi.enable = true;
  lucy.stylix.enable = true;
  lucy.waybar.enable = true;
  lucy.opencode.enable = true;
  lucy.niri.enable = true;
  lucy.gnomeTheme.enable = true;
  lucy.ssh.enable = true;
  lucy.thunderbirdUi.enable = true;
  lucy.vesktop.enable = true;
  lucy.zathura.enable = true;
  lucy.programs.jetbrains-mono = true;
  lucy.programs.nautilus = true;
  lucy.programs.comma = true;
  lucy.programs.android-studio = true;
  lucy.programs.fuzzel = true;

  services.flatpak = {
    enable = true;
    packages = [
      "com.teamspeak.TeamSpeak"
    ];
  };

  programs.nh = {
    enable = true;
    flake = /home/lucy/Documents/dotfiles;
    osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "26.05";
    pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      name = "HelloKittyPeachMilkDonut";
      package = pkgs.callPackage ./cursors/default.nix { };
      size = 32;
    };
    packages = with pkgs; [
      nvd
      nix-tree
    ];
  };

  xdg.desktopEntries = {
    lmstudio = {
      name = "LM Studio";
      genericName = "LLM Runner";
      comment = "Run LLMs locally";
      exec = "lmstudio --no-sandbox %U";
      icon = "lmstudio";
      terminal = false;
      categories = [ "Development" ];
      mimeType = [ "x-scheme-handler/chat" ];
    };
  };

  programs.home-manager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
