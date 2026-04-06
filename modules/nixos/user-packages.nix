{ lib, config, pkgs, ... }:

{
  options = {
    lucy.packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages to install for lucy user";
    };
  };

  config = lib.mkIf (config.lucy.packages != [ ]) {
    users.users.lucy.packages = config.lucy.packages;
  };
}
