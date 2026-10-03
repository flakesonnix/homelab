{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (import ../../lib/types.nix {inherit lib;}) checked dataDirectorySpec;
in {
  # Central storage definitions for the homelab.
  # Each service gets its data directory specification.
  #
  # /data/nextcloud - Nextcloud application state, config, data
  # /data/photos   - Canonical photo library (shared by Nextcloud + Immich)
  # /data/immich   - Immich DB / generated state
  # /data/syncthing - Syncthing configuration and sync data
  # /data/paperless - Paperless documents and media
  # /data/registry  - OCI registry storage
  # /data/attic     - Nix binary cache storage
  # /data/hydra     - Hydra build cache
  # /data/netbox    - NetBox database and uploads
  # /data/librenms  - LibreNMS rrd/log data
  # /data/matrix    - Matrix Synapse database and media
  # /data/rustdesk  - RustDesk database and configuration
  # /data/postgres  - PostgreSQL data (on dedicated microVM)
  # /data/osm       - OpenStreetMap data (Planet, tiles)
  # /data/photos    - Canonical photo library
  # /data/fax       - Fax inbox/outbox (Asterisk)
  # /data/backups   - Backup repositories
  data = {
    nextcloud = {
      path = "/data/nextcloud";
      owner = "nextcloud";
      group = "nextcloud";
      mode = "0750";
      subdirs = ["config" "data" "apps" "state"];
    };

    photos = {
      path = "/data/photos";
      owner = "lucy";
      group = "lucy";
      mode = "0755";
      subdirs = [];
    };

    immich = {
      path = "/data/immich";
      owner = "immich";
      group = "immich";
      mode = "0750";
      subdirs = ["db" "cache" "upload"];
    };

    syncthing = {
      path = "/data/syncthing";
      owner = "syncthing";
      group = "syncthing";
      mode = "0750";
      subdirs = ["config" "data" "folders"];
    };

    paperless = {
      path = "/data/paperless";
      owner = "paperless";
      group = "paperless";
      mode = "0750";
      subdirs = ["consume" "documents" "export" "media" "data"];
    };

    registry = {
      path = "/data/registry";
      owner = "registry";
      group = "registry";
      mode = "0750";
      subdirs = [];
    };

    attic = {
      path = "/data/attic";
      owner = "attic";
      group = "attic";
      mode = "0750";
      subdirs = [];
    };

    hydra = {
      path = "/data/hydra";
      owner = "hydra";
      group = "hydra";
      mode = "0750";
      subdirs = [];
    };

    netbox = {
      path = "/data/netbox";
      owner = "netbox";
      group = "netbox";
      mode = "0750";
      subdirs = [];
    };

    librenms = {
      path = "/data/librenms";
      owner = "librenms";
      group = "librenms";
      mode = "0750";
      subdirs = ["rrd" "logs"];
    };

    matrix = {
      path = "/data/matrix";
      owner = "matrix";
      group = "matrix";
      mode = "0750";
      subdirs = ["db" "media" "uploads"];
    };

    rustdesk = {
      path = "/data/rustdesk";
      owner = "rustdesk";
      group = "rustdesk";
      mode = "0750";
      subdirs = ["db" "config"];
    };

    postgres = {
      path = "/data/postgres";
      owner = "postgres";
      group = "postgres";
      mode = "0750";
      subdirs = [];
    };

    osm = {
      path = "/data/osm";
      owner = "osm";
      group = "osm";
      mode = "0750";
      subdirs = ["planet" "tiles" "data"];
    };

    fax = {
      path = "/data/fax";
      owner = "asterisk";
      group = "asterisk";
      mode = "0750";
      subdirs = ["inbox" "outbox" "queued"];
    };

    backups = {
      path = "/data/backups";
      owner = "lucy";
      group = "lucy";
      mode = "0750";
      subdirs = [];
    };
  };

  # Helper to generate all data directory configurations.
  dataDirConfigs = lib.mapAttrsToList (_name: spec: spec) data;

  # Helper to get a data directory spec.
  getDataDir = name: data.${name};

  # Generate systemd.tmpfiles rules for all data dirs.
  tmpfilesRules =
    lib.concatMap (_name: spec: [
      "d ${spec.path} ${spec.mode} ${spec.owner} ${spec.group} - -"
    ])
    dataDirConfigs;
}
