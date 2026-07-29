{ config, lib, ... }: {
  config = lib.mkIf (config.lucy.topology or {} != {}) {
    topology.self = config.lucy.topology;
  };
}
