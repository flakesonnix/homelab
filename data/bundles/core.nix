{
  moduleFlags = {
    lucy.shell.enable = true;
    lucy.git.enable = true;
    lucy.editor.enable = true;
    lucy.htop.enable = true;
    lucy.btop.enable = true;
    lucy.bat.enable = true;
    lucy.fzf.enable = true;
    lucy.ssh.enable = true;
    lucy.opencode.enable = true;
  };

  packageToggles = [
    "comma"
    "manix"
    "nix-output-monitor"
  ];

  programs.nh = {
    enable = true;
    flake = /home/lucy/Documents/dotfiles;
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "26.05";
    packages = [
      "nvd"
      "nix-tree"
    ];
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
