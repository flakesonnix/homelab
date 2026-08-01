{ lib, config, pkgs, ... }: let
  cfg = config.lucy.cups;
in {
  options.lucy.cups = {
    enable = lib.mkEnableOption "CUPS print server with driverless IPP printers";

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["*:631"];
      description = "Addresses CUPS listens on";
    };

    browsing = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable printer browsing";
    };

    defaultShared = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Share printers by default";
    };

    allowFrom = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["all"];
      description = "Allowed networks/hosts for printing";
    };

    drivers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [pkgs.foomatic-db];
      description = "Printer driver packages";
    };

    printers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.nonEmptyStr;
            description = "Printer name (no spaces)";
          };
          location = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Printer location";
          };
          deviceUri = lib.mkOption {
            type = lib.types.str;
            description = "Device URI (e.g., ipp://10.8.0.197/ipp/print or file:///dev/printer/name)";
          };
          model = lib.mkOption {
            type = lib.types.str;
            default = "everywhere";
            description = "PPD model (use 'everywhere' for driverless IPP)";
          };
          ppdOptions = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { PageSize = "A4"; };
            description = "PPD options";
          };
          isDefault = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Set as default printer";
          };
        };
      });
      default = [];
      description = "List of printers to configure";
    };

    avahi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Advertise printers via Avahi mDNS";
    };

    extraConf = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra cupsd.conf snippets";
    };
  };

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      listenAddresses = cfg.listenAddresses;
      browsing = cfg.browsing;
      defaultShared = cfg.defaultShared;
      allowFrom = cfg.allowFrom;
      drivers = cfg.drivers;
      extraConf = cfg.extraConf;
    };

    hardware.printers = {
      ensureDefaultPrinter = lib.optionalString
        (builtins.any (p: p.isDefault) cfg.printers)
        (builtins.head (builtins.filter (p: p.isDefault) cfg.printers)).name;
      ensurePrinters = lib.map (p: {
        name = p.name;
        location = p.location;
        deviceUri = p.deviceUri;
        model = p.model;
        ppdOptions = p.ppdOptions;
      }) cfg.printers;
    };

    services.avahi = lib.mkIf cfg.avahi {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
  };
}