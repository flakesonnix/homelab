{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/packages.nix
    ./programs/easyeffects
    ./programs/htop.nix
    ./programs/btop.nix
    ./programs/gnome-theme.nix
    ./programs/openclaude.nix
    ../../modules/home/stylix.nix
    ../../modules/home/ssh.nix
    ../../modules/home/waybar.nix
    ../../modules/home/opencode.nix
    ../../modules/home/niri.nix
  ];

  lucy.shell.enable = true;
  lucy.git.enable = true;
  lucy.editor.enable = true;
  lucy.easyeffects.enable = true;
  lucy.htop.enable = true;
  lucy.btop.enable = true;
  lucy.stylix.enable = true;
  lucy.waybar.enable = true;
  lucy.opencode.enable = true;
  lucy.niri.enable = true;
  lucy.gnomeTheme.enable = true;
  lucy.ssh.enable = true;
  lucy.programs.jetbrains-mono = true;
  lucy.programs.nautilus = true;
  lucy.programs.wpaperd = true;
  lucy.programs.comma = true;
  lucy.programs.android-studio = true;
  lucy.programs.fuzzel = true;
  lucy.openclaude.enable = true;

  programs.neovim = {
    withRuby = true;
    withPython3 = true;
  };

  services.flatpak = {
    enable = true;
    packages = [
      "com.teamspeak.TeamSpeak"
    ];
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
