{ lib, config, ... }:

{
  imports = [
    ../modules/nixos
  ];

  options = {
    lucy.enableFirefox = lib.mkEnableOption "Firefox browser";
  };

  config = {
    environment.sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    nixpkgs.config.allowUnfree = true;

    programs.firefox = lib.mkIf config.lucy.enableFirefox {
      enable = true;
      policies = {
        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          };
        };
      };
    };

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
  };
}
