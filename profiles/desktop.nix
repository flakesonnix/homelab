{lib, ...}: {
  imports = [
    ./base.nix
  ];

  services.xserver.xkb = {
    layout = lib.mkDefault "us";
    variant = "";
  };

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = true;
    pulse.enable = lib.mkDefault true;
  };
}
