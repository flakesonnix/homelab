{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types mkForce;
  inherit (import ../../lib/types.nix {inherit lib;}) checked;
in {
  # ── mkStorageVolume ─────────────────────────────────────
  # Creates a storage volume definition for a microVM.
  mkStorageVolume = {
    name,
    mountPoint,
    size,
    user,
    group,
    ...
  }: {
    image = "${name}.img";
    mountPoint = mountPoint;
    size = size;
    inherit user group;
  };

  # ── mkStorageShare ──────────────────────────────────────
  # Creates a virtiofs share for a microVM.
  mkStorageShare = {
    tag,
    source,
    mountPoint,
    readOnly ? true,
    proto ? "virtiofs",
    ...
  }: {
    inherit tag source mountPoint readOnly proto;
  };

  # ── mkDataDirectoryHost ─────────────────────────────────
  # Creates host-side data directory configuration with proper
  # permissions and ACLs.
  mkDataDirectoryHost = {
    path,
    owner,
    group,
    mode ? "0750",
    ...
  }: {
    fileSystems."${path}" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["defaults" "size=100%" "mode=0750"];
    };
    systemd.tmpfiles.rules = [
      "d ${path} ${mode} ${owner} ${group} - -"
    ];
  };

  # ── mkBackupPolicy ──────────────────────────────────────
  # Creates restic backup configuration for data directories.
  mkBackupPolicy = {
    name,
    paths,
    schedule ? "daily",
    repository ? "/data/backups/${name}",
    ...
  }: {
    services.restic.backups.${name} = {
      enable = true;
      inherit paths;
      inherit repository;
      passwordFile = "/run/secrets/backup/${name}";
      machineId = "mireo";
      timerConfig = {
        OnCalendar = schedule;
        Persistent = true;
      };
      pruneOpts = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6"];
    };
  };

  # ── mkPostgreSQLBackup ──────────────────────────────────
  # Creates a PostgreSQL backup service via pg_dump.
  mkPostgreSQLBackup = {
    name,
    database,
    user,
    host,
    port,
    ...
  }: {
    services.restic.backups."${name}-db" = {
      enable = true;
      paths = [];
      command = "${pkgs.postgresql}/bin/pg_dump -h ${host} -p ${toString port} -U ${user} ${database} | restic backup --stdin --stdin-filename ${database}.sql";
      repository = "/data/backups/${name}-db";
      passwordFile = "/run/secrets/backup/${name}";
      machineId = "mireo";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };

  # ── mkQuota ─────────────────────────────────────────────
  # Creates filesystem quota configuration for a data directory.
  mkQuota = {
    path,
    size,
    ...
  }: {
    fileSystems."${path}" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["defaults,size=${toString size}M"];
    };
  };
}
