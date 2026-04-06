{ lib, config, pkgs, ... }:

{
  options.lucy.basePackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Base packages for all hosts";
  };

  options.lucy.hostPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Host-specific packages";
  };

  config = {
    users.users.lucy.packages = config.lucy.basePackages ++ config.lucy.hostPackages;
  };
}
