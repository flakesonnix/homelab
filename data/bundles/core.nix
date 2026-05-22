{
  meta = {
    description = "Base shell, editor, SSH, and Nix workflow configuration";
    targets = ["home"];
  };

  programs = {
    bash.enable = true;
    git.enable = true;
    neovim.enable = true;
    htop.enable = true;
    btop.enable = true;
    bat.enable = true;
    fzf.enable = true;
    ssh.enable = true;
    opencode.enable = true;
      nh = {
        enable = true;
        flake = "/home/lucy/Documents/dotfiles";
      };
  };

  packageToggles = [
    "comma"
    "manix"
    "nix-output-monitor"
  ];

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "26.05";
    pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      name = "HelloKittyPeachMilkDonut";
      size = 32;
    };
  };

  programs.home-manager.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];
}
