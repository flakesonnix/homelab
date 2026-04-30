{
  config,
  lib,
  ...
}: let
  cfg = config.lucy.serialGetty;
in {
  options.lucy.serialGetty.disabled = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Serial TTY devices whose systemd getty units should be disabled.";
  };

  config = lib.mkIf (cfg.disabled != []) {
    systemd.services = lib.genAttrs (map (tty: "serial-getty@${tty}") cfg.disabled) (_: {
      enable = false;
    });
  };
}
