{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (import ../../lib/types.nix {inherit lib;}) checked dbSpec dbResult reverseProxySpec reconcilerSpec oidcClientSpec firewallRuleSpec dataDirectorySpec serviceDefSpec siteSpec deviceSpec;
in {
  # ── mkPostgresDatabase ──────────────────────────────────
  # Generates a complete PostgreSQL database setup from a spec:
  # database + user + password secret + pg_hba entry.
  mkPostgresDatabase = spec:
    checked dbSpec spec
    // {
      passwordSecret = spec.passwordSecret;
      ensureDatabases = [
        {
          name = spec.name;
          owner = spec.owner;
          port = spec.port;
        }
      ];
      ensureUsers = [
        {
          name = spec.owner;
          ensurePermissions = {
            "DATABASE ${spec.name}" = "ALL";
          };
          passwordFile = "/run/secrets/${spec.passwordSecret}";
        }
      ];
    };

  # mkPostgresDatabaseList generates multiple databases from a list.
  mkPostgresDatabases = specs: map mkPostgresDatabase specs;

  # ── mkServiceUser ───────────────────────────────────────
  # Creates a system user + group for a service.
  mkServiceUser = {name, ...}: {
    users.users.${name} = {
      isSystemUser = true;
      group = name;
    };
    users.groups.${name} = {};
  };

  # ── mkDataDirectory ─────────────────────────────────────
  # Creates a data directory with proper permissions and tmpfiles.
  mkDataDirectory = spec: let
    s = checked dataDirectorySpec spec;
  in {
    fileSystems.${s.path} = lib.mkForce (
      if s.path == "/data"
      then null
      else {
        device = "tmpfs";
        fsType = "tmpfs";
        options = ["defaults" "size=100%" "mode=0750"];
      }
    );
    systemd.tmpfiles.rules = [
      "d ${s.path} ${s.mode} ${s.owner} ${s.group} - -"
    ];
  };

  # ── mkReverseProxy ──────────────────────────────────────
  # Generates nginx virtualHost + TLS + ACME configuration
  # for a reverse proxy target.
  mkReverseProxy = spec: let
    s = checked reverseProxySpec spec;
  in {
    services.nginx.virtualHosts.${s.host} = {
      enableACME = s.tls;
      forceSSL = s.tls;
      basicAuth = null;
      locations."/".proxyPass = s.upstream;
      locations."/".proxyWebsockets = true;
      extraConfig = s.extraConfig;
    };
    security.acme.certs.${s.host} = lib.mkIf s.tls {
      acceptTerms = true;
      email = null;
    };
  };

  # ── mkFirewallRule ──────────────────────────────────────
  # Generates firewall rules for a service.
  mkFirewallRule = spec: let
    s = checked firewallRuleSpec spec;
  in {
    networking.firewall.allowedTCPPorts = lib.optionals (s.protocol == "tcp" || s.protocol == "both") s.ports;
    networking.firewall.allowedUDPPorts = lib.optionals (s.protocol == "udp" || s.protocol == "both") s.ports;
  };

  # ── mkOIDCClient ────────────────────────────────────────
  # Generates Keycloak OIDC client configuration reference.
  mkOIDCClient = spec: let
    s = checked oidcClientSpec spec;
  in {
    name = s.name;
    clientId = s.clientId;
    clientSecretSecret = s.clientSecretSecret;
    redirectUri = s.redirectUri;
    scopes = s.scopes;
    issuer = s.issuer;
  };

  # ── mkBackupPolicy ──────────────────────────────────────
  # Generates backup configuration for a service.
  mkBackupPolicy = {
    name,
    paths,
    databases ? [],
    schedule ? "daily",
  }: {
    services.restic.backups.${name} = {
      enable = true;
      paths = paths;
      repository = "/data/backups/${name}";
      passwordFile = "/run/secrets/backup/${name}";
      machineId = "mireo";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };

  # ── mkPrometheusExporter ────────────────────────────────
  # Generates node_exporter configuration.
  mkPrometheusExporter = enable: {
    services.prometheus = {
      enable = enable;
      port = 9100;
      scrapeConfigs = [];
    };
  };

  # ── mkSopsSecret ──────────────────────────────────
  # Generates a sops.secrets reference for the data/hosts/mireo
  # services.nix file.
  mkSopsSecret = name: {
    sops = {
      secrets."${name}" = {};
    };
  };
}
