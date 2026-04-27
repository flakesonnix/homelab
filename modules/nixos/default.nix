{lib, ...}: {
  imports = [
    ./base.nix
    ./gnome.nix
    ./hyprland.nix
  ];

  options.lucy.nixos = {
    enable = lib.mkEnableOption "lucy's NixOS system configuration";
  };

  config = lib.mkIf (lib.mkDefault false) {};
}
