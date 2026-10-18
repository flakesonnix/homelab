{
  config,
  pkgs,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-freebsd";
  system.stateVersion = "26.11";
  networking.hostName = "p53-nixbsd";
  networking.dhcpcd.wait = "background";
  environment.etc.localtime.source = "${pkgs.tzdata}/share/zoneinfo/Europe/Berlin";

  boot.loader.stand-freebsd.enable = true;

  fileSystems."/" = {
    device = "/dev/gpt/nixos";
    fsType = "ufs";
  };
  fileSystems."/boot" = {
    device = "/dev/msdosfs/ESP";
    fsType = "msdosfs";
  };

  # Console-only bootstrap. Set passwords on first boot; never expose SSH here.
  users.mutableUsers = true;
  users.users.root.initialHashedPassword = "";
  users.users.lucy = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    initialHashedPassword = "!";
  };
  services.openssh.enable = false;

  # NOTE: kein fastfetch hier: zieht über chafa → libjxl → gdk-pixbuf →
  # libtiff → lerc einen kaputten lerc-Patch (FreeBSD-Cross, „Reversed patch
  # detected") und damit den gesamten Image-Build runter. Fetch-Tool ist
  # hyfetch (liefert neowofetch als neofetch-Nachfolger gleich mit).
  environment.systemPackages = with pkgs; [git vim htop hyfetch];
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nixbsd.enableExtraSubstituters = false;

  virtualisation.vmVariant.virtualisation = {
    diskImage = "./${config.system.name}.qcow2";
    memorySize = 4096;
    cores = 4;
    rootSize = "32g";
    bootPartition = "/dev/msdosfs/ESP";
  };
}
