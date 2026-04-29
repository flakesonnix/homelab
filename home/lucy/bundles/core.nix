{
  pkgs,
  ...
}: {
  lucy.shell.enable = true;
  lucy.git.enable = true;
  lucy.editor.enable = true;
  lucy.htop.enable = true;
  lucy.btop.enable = true;
  lucy.bat.enable = true;
  lucy.fzf.enable = true;
  lucy.ssh.enable = true;
  lucy.opencode.enable = true;

  lucy.programs.comma = true;
  lucy.programs.manix = true;
  lucy.programs.nix-output-monitor = true;

  programs.nh = {
    enable = true;
    flake = /home/lucy/Documents/dotfiles;
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "26.05";
    packages = with pkgs; [
      nvd
      nix-tree
    ];
    pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      name = "HelloKittyPeachMilkDonut";
      package = pkgs.callPackage ../cursors/default.nix {};
      size = 32;
    };
  };

  programs.home-manager.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];
}
