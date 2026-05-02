{
  config,
  lib,
  ...
}: let
  cfg = config.lucy.gaming;
  inherit (cfg) sysctl;
in {
  config = lib.mkIf (cfg.enable && sysctl.enable) {
    boot.kernel.sysctl = lib.filterAttrs (_: v: v != null) {
      # Scheduler
      "kernel.sched_migration_cost_ns" = sysctl.scheduler.migrationCostNs;
      "kernel.sched_latency_ns" = sysctl.scheduler.latencyNs;

      # Memory
      "vm.max_map_count" = sysctl.memory.maxMapCount;
      "vm.dirty_ratio" = sysctl.memory.dirtyRatio;

      # Filesystem
      "fs.inotify.max_user_watches" = sysctl.fs.inotifyMaxWatches;

      # Network
      "net.core.rmem_max" =
        if sysctl.network.lowLatency
        then sysctl.network.rmemMax
        else null;
      "net.core.wmem_max" =
        if sysctl.network.lowLatency
        then sysctl.network.wmemMax
        else null;
      "net.ipv4.tcp_low_latency" =
        if sysctl.network.lowLatency
        then sysctl.network.tcpLowLatency
        else null;
    };
  };
}
