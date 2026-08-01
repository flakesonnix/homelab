{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.nixServe;
in {
  options.lucy.nixServe = {
    enable = lib.mkEnableOption "nix-serve-ng binary cache server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix-serve-ng;
      description = "Package providing nix-serve (use pkgs.nix-serve-ng for the faster rewrite)";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP address to listen on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port to listen on";
    };

    extraParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra command-line options passed to nix-serve";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the port in the firewall";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nix-serve = {
      enable = true;
      package = cfg.package;
      bindAddress = cfg.bindAddress;
      port = toString cfg.port;
      extraParams = cfg.extraParams;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
  };
}
