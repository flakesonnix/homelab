# Minecraft Java + Geyser server (systemd wrapper around a manually
# maintained server directory, e.g. /home/lucy/mcserver with Paper's
# server.jar, world, plugins).
#
# Only the SERVICE is declarative: world, configs, plugins and the jar
# itself stay manual files (nothing is overwritten). The unit runs as
# cfg.user (default lucy) with WorkingDirectory=cfg.dataDir, so relative
# paths, plugin data and EULA handling behave exactly like a manual
# `java -jar server.jar nogui` start.
#
# Console: there is none attached (StandardInput null). Logs via
# `journalctl -u minecraft -f` plus the server's own logs/ dir. In-game
# admin works via ops.json; start/stop/restart via systemctl — user
# cfg.user may manage the unit without root (polkit rule below).
# Geyser/Floodgate run as plugins in the same JVM (same ports as manual).
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.services.minecraft;
in {
  config = lib.mkIf cfg.enable {
    systemd.services.minecraft = {
      description = "Minecraft Java + Geyser server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.javaPackage}/bin/java -Xms${cfg.memory} -Xmx${cfg.memory} -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar ${cfg.jar} nogui";
        Restart = "on-failure";
        RestartSec = "30s";
        # World save on /stop can take a while; SIGTERM triggers Paper's
        # clean shutdown, exit code 0 means "left alone" (no restart).
        TimeoutStopSec = "120s";
      };
    };

    # cfg.user manages the unit without root password (start/stop/restart;
    # same pattern as the libvirt rule in data/hosts/mireo/settings.nix).
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${cfg.user}" &&
            action.lookup("unit") == "minecraft.service") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
