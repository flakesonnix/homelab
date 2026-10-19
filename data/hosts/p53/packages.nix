{
  pkgs,
  wrappers,
  ...
}: let
  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in {
  basePackages = with pkgs; [
    alacritty
    emacs-pgtk
    zathura
    fzf
    bat
    mcp-nixos
    vesktop
    vlc
    p7zip
    thunderbird
    deskflow
    keepassxc
    nodejs_22
    ausweisapp
    kdePackages.kdenlive
    ani-cli
    scdl
    age
    cloc
  ];

  systemPackages = [hyfetch-wrapped pkgs.fastfetch];

  fontPackages = with pkgs; [
    hack-font
    nerd-fonts.hack
    font-awesome
  ];
}
