{ config, pkgs, lib, ... }:

{
  options.lucy.packages = {
    enable = lib.mkEnableOption "lucy's additional packages";
    list = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of packages to install for lucy";
    };
  };

  config = lib.mkIf config.lucy.packages.enable {
    home.packages = config.lucy.packages.list;
  };
}
