{ lib, ... }:

{
  imports = [
    ../modules/nixos
  ];

  environment.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
  };

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;

  services.printing.enable = true;

  security.rtkit.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  system.stateVersion = lib.mkDefault "25.11";
}
