{ lib, config, pkgs, ... }:

{
  options = {
    lucy.basePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Base packages for all hosts";
    };

    lucy.hostPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Host-specific packages";
    };
  };

  config = {
    users.users.lucy.packages = config.lucy.basePackages ++ config.lucy.hostPackages;

    environment.systemPackages = with pkgs; [
      nodejs_22
      gnome-tweaks
    ];

    programs.npm = {
      enable = true;
      package = pkgs.nodejs_22;
    };
  };
}
