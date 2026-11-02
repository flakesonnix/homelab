{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./base.nix
  ];

  services.xserver.xkb = {
    layout = lib.mkDefault "us";
    variant = "";
  };

  fonts.packages = with pkgs; [
    iosevka
    nerd-fonts.symbols-only
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.defaultFonts = {
    serif = [ "Iosevka" ];
    sansSerif = [ "Iosevka" ];
    monospace = [
      "Iosevka"
      "Symbols Nerd Font Mono"
    ];
    emoji = [ "Noto Color Emoji" ];
  };

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = true;
    pulse.enable = lib.mkDefault true;
  };
}
