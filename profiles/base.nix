{
  lib,
  config,
  ...
}: {
  imports = [
    ../modules/nixos
  ];

  config = {
    environment.sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    nixpkgs.config.allowUnfree = true;

    services.printing.enable = lib.mkDefault (!config.lucy.base.isServer);

    security.rtkit.enable = lib.mkDefault (!config.lucy.base.isServer);

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
  };
}
