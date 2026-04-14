{ lib, config, pkgs, ... }:

let
  cfg = config.lucy.dect;
in

{
  options.lucy.dect = {
    enable = lib.mkEnableOption (lib.mdDoc ''
      OsmocomDECT base station with COM-ON-AIR PCMCIA hardware support.
      
      This module provides DECT phone base station functionality using
      the Quicklogic Corporation COM-ON-AIR Dosch&Amand DECT PCMCIA card.
    '');

    rfpConnection = lib.mkOption {
      type = lib.types.str;
      default = "osmo-dect";
      description = lib.mdDoc "RFP (Radio Fixed Part) connection string";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libosmocore
      libosmoabis
      libosmo-netif
    ];

    # The com-on-air driver needs to be loaded
    boot.extraModulePackages = [ ];

    boot.kernelModules = [
      "com-on-air"  # May need custom kernel module
    ];

    # TODO: osmo-dect is not in nixpkgs - need to build from source
    # See: https://osmocom.org/projects/dect
  };
}