/*
* Declarative Uptime Kuma monitors (GitOps sync, host-side)
*
* The nixpkgs module only covers server knobs (HOST/PORT via settings);
* monitors/users/notifications live in SQLite. This module reconciles the
* monitor set over the HTTP API (python3Packages.uptime-kuma-api):
* Nix is authoritative — missing monitors are created, drifted ones are
* updated, extras are DELETED. UI edits between syncs get overwritten.
*
* Runs on the mireo HOST (not in the VM): no secret sharing into the
* guest needed, the admin password stays in host sops (/run/secrets).
* oneshot at boot + daily timer (Persistent) for convergence.
* Notifications are NOT managed (none exist; needs channel + secrets —
* follow-up once a channel is chosen).
*
* Debugging: systemctl status uptime-kuma-sync; dry-run preview:
*   /etc/uptime-kuma-sync/preview --dry-run   (needs passwordFile present)
* Manual re-sync: systemctl start uptime-kuma-sync
*/
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.uptime-kuma-sync;

  py = pkgs.python3.withPackages (ps: [ps.uptime-kuma-api]);

  # Store-safe JSON (names/targets only, no secrets).
  desiredJson = pkgs.writeText "uptime-kuma-monitors.json" (builtins.toJSON
    (lib.mapAttrs (name: m: {
        inherit name;
        inherit (m) type target interval maxRetries dnsServer dnsType;
        port = m.port;
      })
      cfg.monitors));

  syncScript = pkgs.writeTextFile {
    name = "uptime-kuma-sync.py";
    executable = true;
    text = ''
      #!${py}/bin/python
      """Reconcile Uptime Kuma monitors with Nix-defined desired state."""
      import argparse
      import json
      import sys

      from uptime_kuma_api import Event, MonitorType, UptimeKumaApi
      from uptime_kuma_api.api import _check_arguments_monitor, _convert_monitor_input


      def api_add_monitor(api, **kwargs):
          """add_monitor backport for kuma>=2.0: lib 1.2.1 omits the NOT
          NULL `conditions` column -> SQLITE_CONSTRAINT on INSERT.
          edit_monitor is unaffected (merges the server object which
          already carries conditions). Remove once nixpkgs ships
          uptime-kuma-api with conditions support."""
          data = api._build_monitor_data(**kwargs)
          data["conditions"] = []
          _convert_monitor_input(data)
          _check_arguments_monitor(data)
          with api.wait_for_event(Event.MONITOR_LIST):
              return api._call("add", data)

      TYPES = {
          "http": MonitorType.HTTP,
          "ping": MonitorType.PING,
          "port": MonitorType.PORT,
          "dns": MonitorType.DNS,
      }


      def log(msg):
          print(f"uptime-kuma-sync: {msg}", flush=True)


      def kuma_kwargs(name, spec):
          base = {
              "name": name,
              "interval": spec["interval"],
              "maxretries": spec["maxRetries"],
              "notificationIDList": [],
          }
          t = spec["type"]
          if t == "http":
              return base | {"type": TYPES[t], "url": spec["target"]}
          if t == "ping":
              return base | {"type": TYPES[t], "hostname": spec["target"]}
          if t == "port":
              return base | {"type": TYPES[t], "hostname": spec["target"], "port": spec["port"]}
          if t == "dns":
              return base | {
                  "type": TYPES[t],
                  "hostname": spec["target"],
                  "dns_resolve_server": spec["dnsServer"],
                  "dns_resolve_type": spec["dnsType"],
                  "port": 53,
              }
          raise SystemExit(f"unknown monitor type: {t}")


      def norm_server(m):
          notifs = m.get("notificationIDList") or []
          if isinstance(notifs, dict):
              notifs = sorted(notifs.keys())
          else:
              notifs = sorted(notifs)
          return {
              "type": m.get("type"),
              "url": m.get("url") or None,
              "hostname": m.get("hostname") or None,
              "port": m.get("port"),
              "interval": m.get("interval"),
              "maxretries": m.get("maxretries", m.get("maxRetries")),
              "notifications": notifs,
          }


      def norm_desired(name, spec):
          kw = kuma_kwargs(name, spec)
          return {
              # Enum -> plain value for comparison with server strings.
              "type": kw["type"].value if hasattr(kw["type"], "value") else kw["type"],
              "url": kw.get("url"),
              "hostname": kw.get("hostname"),
              "port": kw.get("port"),
              "interval": kw["interval"],
              "maxretries": kw["maxretries"],
              "notifications": [],
          }


      def main():
          ap = argparse.ArgumentParser()
          ap.add_argument("--api-url", required=True)
          ap.add_argument("--username", required=True)
          ap.add_argument("--password-file", required=True)
          ap.add_argument("--monitors", required=True)
          ap.add_argument("--dry-run", action="store_true")
          args = ap.parse_args()

          try:
              with open(args.password_file, encoding="utf-8") as f:
                  password = f.read().splitlines()[0]
          except (OSError, IndexError):
              log(f"password file {args.password_file} missing or empty "
                  f"(sops.secrets not declared? see docs/secrets.md)")
              return 1
          with open(args.monitors, encoding="utf-8") as f:
              desired = json.load(f)

          api = UptimeKumaApi(args.api_url, timeout=15)
          try:
              api.login(args.username, password)
          except Exception as e:  # noqa: BLE001 - surface any auth/conn error
              log(f"login as {args.username} failed: {e}")
              return 1
          try:
              existing = {m["name"]: m for m in api.get_monitors()}
              changed = False
              for name, spec in desired.items():
                  want = norm_desired(name, spec)
                  have = norm_server(existing[name]) if name in existing else None
                  if have is None:
                      log(f"+ create {spec['type']} {name}")
                      if not args.dry_run:
                          api_add_monitor(api, **kuma_kwargs(name, spec))
                      changed = True
                  elif have != want:
                      log(f"~ update {name} (drift: "
                          + ", ".join(k for k in want if want[k] != have.get(k)) + ")")
                      if not args.dry_run:
                          api.edit_monitor(existing[name]["id"], **kuma_kwargs(name, spec))
                      changed = True
              for name, m in existing.items():
                  if name not in desired:
                      log(f"- delete {name} (not in Nix)")
                      if not args.dry_run:
                          api.delete_monitor(m["id"])
                      changed = True
              if not changed:
                  log(f"in sync ({len(desired)} monitors)")
              elif args.dry_run:
                  log("dry-run: no writes performed")
              return 0
          finally:
              api.disconnect()


      if __name__ == "__main__":
          sys.exit(main())
    '';
  };
in {
  options.services.uptime-kuma-sync = {
    enable = lib.mkEnableOption "declarative Uptime Kuma monitor sync (Nix-authoritative, API-based)";

    apiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://10.8.0.9:3001";
      description = "Uptime Kuma base URL (direct VM address, no Caddy dependency).";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "lucy";
      description = "Admin username for API login.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Absolute runtime path to a file with the admin password.
        Only the path enters the Nix store, never the secret:
          sops.secrets."uptime-kuma/admin-password" = {};
          services.uptime-kuma-sync.passwordFile =
            "/run/secrets/uptime-kuma/admin-password";
      '';
    };

    monitors = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum ["http" "ping" "port" "dns"];
            description = "Check type.";
          };
          target = lib.mkOption {
            type = lib.types.str;
            description = "URL (http), hostname/IP (ping/port/dns).";
          };
          port = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            description = "TCP port (required for type=port).";
          };
          interval = lib.mkOption {
            type = lib.types.ints.positive;
            default = 60;
            description = "Check interval in seconds.";
          };
          maxRetries = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 1;
            description = "Retries before paging DOWN.";
          };
          dnsServer = lib.mkOption {
            type = lib.types.str;
            default = "10.8.0.1";
            description = "Resolver for type=dns (default: our LAN DNS — also tests dnsmasq).";
          };
          dnsType = lib.mkOption {
            type = lib.types.str;
            default = "A";
            description = "Record type for type=dns.";
          };
        };
      });
      default = {};
      description = ''
        Monitors keyed by display name. Authoritative: extras on the
        server are deleted. Example:
          monitors.grafana = { type = "http"; target = "http://10.8.0.2:3000/"; };
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.passwordFile != "" && lib.hasPrefix "/" cfg.passwordFile;
        message = ''services.uptime-kuma-sync: passwordFile must be an absolute runtime path (e.g. "/run/secrets/uptime-kuma/admin-password").'';
      }
      {
        assertion = lib.all (m: m.type != "port" || m.port != null) (builtins.attrValues cfg.monitors);
        message = "services.uptime-kuma-sync: type=port monitors need port set.";
      }
      {
        assertion = lib.all (m: m.type != "http" || lib.hasPrefix "http" m.target) (builtins.attrValues cfg.monitors);
        message = "services.uptime-kuma-sync: type=http monitors need an http(s) URL target.";
      }
    ];

    warnings =
      lib.mapAttrsToList
      (_name: m: "services.uptime-kuma-sync: monitor target '${m.target}' points into the Nix store — did you mean a runtime address?")
      (lib.filterAttrs (_name: m: lib.hasPrefix "/nix/store" m.target) cfg.monitors);

    systemd.services.uptime-kuma-sync = {
      description = "Sync declarative Uptime Kuma monitors (authoritative)";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "microvm@uptime-kuma.service"];
      serviceConfig.Type = "oneshot";
      script = ''
        set -eu
        exec ${syncScript} \
          --api-url "${cfg.apiUrl}" \
          --username "${cfg.username}" \
          --password-file "${cfg.passwordFile}" \
          --monitors "${desiredJson}"
      '';
    };

    systemd.timers.uptime-kuma-sync = {
      description = "Daily Uptime Kuma monitor convergence";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Dry-run preview without writes (needs passwordFile present):
    #   /etc/uptime-kuma-sync/preview
    environment.etc."uptime-kuma-sync/preview" = {
      mode = "0555";
      source = pkgs.writeShellScript "uptime-kuma-sync-preview" ''
        exec ${syncScript} \
          --api-url "${cfg.apiUrl}" \
          --username "${cfg.username}" \
          --password-file "${cfg.passwordFile}" \
          --monitors "${desiredJson}" \
          --dry-run
      '';
    };
  };
}
