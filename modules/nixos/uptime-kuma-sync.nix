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
* Timer-driven only (boot + daily, Persistent) for convergence: the
* service is deliberately NOT wanted by multi-user.target, so a transient
* API outage (e.g. kuma VM restarting mid-switch) can never fail a
* nixos-rebuild/deploy and trigger a rollback. Sync right after a monitor
* change: systemctl start uptime-kuma-sync (timer retries daily anyway).
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

  # Store-safe JSON (names/targets/groups/tags only, no secrets).
  desiredJson = pkgs.writeText "uptime-kuma-monitors.json" (builtins.toJSON
    (lib.mapAttrs (name: m: {
        inherit name;
        inherit (m) type target interval maxRetries dnsServer dnsType group tags;
        port = m.port;
      })
      cfg.monitors));

  # Empty slug = status page unmanaged (script skips).
  statusPageJson = pkgs.writeText "uptime-kuma-status-page.json" (builtins.toJSON
    (
      if cfg.statusPage.enable
      then {
        inherit (cfg.statusPage) slug title description;
        monitors = builtins.attrNames cfg.monitors;
      }
      else {slug = "";}
    ));

  syncScript = pkgs.writeTextFile {
    name = "uptime-kuma-sync.py";
    executable = true;
    text = ''
      #!${py}/bin/python
      """Reconcile Uptime Kuma monitors with Nix-defined desired state."""
      import argparse
      import json
      import sys
      import urllib.request

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


      # lib 1.2.1 _build_status_page_data params (pinned: extra server keys
      # must not reach it as **kwargs, and analyticsType isn't one of them).
      _STATUS_PAGE_PARAMS = {
          "slug", "id", "title", "description", "theme", "published",
          "showTags", "domainNameList", "googleAnalyticsId", "customCSS",
          "footerText", "showPoweredBy", "showCertificateExpiry", "icon",
          "publicGroupList",
      }


      def save_status_page_v2(api, api_url, slug, **kwargs):
          """save_status_page backport for kuma>=2.1: lib 1.2.1 crashes in
          get_status_page (`incident` renamed to `incidents`, KeyError) and
          omits analyticsType (v2 rejects the save with "Invalid analytics
          type"). Mirrors the lib's save path with raw calls. Remove once
          nixpkgs ships a v2-capable lib (upstream is unmaintained; the
          maintained fork is uptime-kuma-api2)."""
          r1 = api._call("getStatusPage", slug)
          with urllib.request.urlopen(f"{api_url}/api/status-page/{slug}",
                                       timeout=15) as resp:
              r2 = json.load(resp)
          config = r1["config"]
          config.update(r2["config"])
          status_page = {
              **config,
              "publicGroupList": r2["publicGroupList"],
              "maintenanceList": r2.get("maintenanceList", []),
          }
          status_page.pop("incident", None)
          status_page.pop("incidents", None)
          status_page.pop("maintenanceList")
          status_page.update(kwargs)
          # slug travels as our own argument (don't rely on the server
          # echoing it inside config).
          status_page["slug"] = slug
          params = {k: v for k, v in status_page.items()
                    if k in _STATUS_PAGE_PARAMS}
          _slug, config, icon, groups = api._build_status_page_data(**params)
          # v2 requires analyticsType present (null = no analytics).
          config["analyticsType"] = status_page.get("analyticsType")
          r = api._call("saveStatusPage", (_slug, config, icon, groups))
          # refresh cached list like the lib does (it misses save events)
          cache = api._event_data.setdefault(Event.STATUS_PAGE_LIST, {})
          cache[str(config["id"])] = api._call("getStatusPage", slug)["config"]
          return r

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
          ap.add_argument("--status-page", required=True)
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
              live = {m["name"]: m["id"] for m in existing.values()}
              changed = False
              for name, spec in desired.items():
                  want = norm_desired(name, spec)
                  have = norm_server(existing[name]) if name in existing else None
                  if have is None:
                      log(f"+ create {spec['type']} {name}")
                      if not args.dry_run:
                          res = api_add_monitor(api, **kuma_kwargs(name, spec)) or {}
                          # Track the id locally: the lib caches the monitor
                          # list, a refetch here would still miss the newborn.
                          if res.get("monitorID") is not None:
                              live[name] = res["monitorID"]
                          else:
                              live = {m["name"]: m["id"] for m in api.get_monitors()}
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
                      live.pop(name, None)
                      changed = True
              if not changed:
                  log(f"in sync ({len(desired)} monitors)")
              elif args.dry_run:
                  log("dry-run: no writes performed")
              # Tags are annotations, not contract: loud log on failure,
              # never fail the sync (or the deploy) over them.
              try:
                  sync_monitor_tags(api, desired, live, existing,
                                    args.dry_run)
              except Exception as e:  # noqa: BLE001
                  log(f"tags failed, monitors are in sync: {e}")
              with open(args.status_page, encoding="utf-8") as f:
                  page = json.load(f)
              if page.get("slug"):
                  # NOTE: live is the tracked dict from above (creates and
                  # deletes applied) — do NOT refetch here, the lib caches
                  # the monitor list and would miss newborns.
                  # Page failures must never fail the whole sync (and with
                  # it the deploy): monitors are the contract, the page is
                  # presentation. Loud log, next run retries.
                  try:
                      sync_status_page(api, args.api_url, page, live, desired, args.dry_run)
                  except Exception as e:  # noqa: BLE001
                      log(f"status page failed, monitors are in sync: {e}")
              return 0
          finally:
              api.disconnect()


      # Display order of the status page categories = sites (groups not
      # listed here sort in alphabetically after the known ones).
      GROUP_ORDER = ["Homelab", "Internet", "Remote"]


      def sync_monitor_tags(api, desired, live, existing, dry_run):
          """Ensure monitor tag assignments: automatic `target` tag (so the
          probed address is one click away in the UI) plus the Nix `tags`
          map. Additive only — UI-added tags are never deleted. Failures
          are loud but never fail the sync (annotations, not contract)."""
          try:
              server_tags = {t["name"]: t for t in api.get_tags()}
          except Exception as e:  # noqa: BLE001
              log(f"tags skipped (cannot list server tags): {e}")
              return
          for name, spec in desired.items():
              if name not in live:
                  continue
              want = {"target": spec["target"]}
              want.update(spec.get("tags", {}))
              have = set()
              for t in existing.get(name, {}).get("tags", []) or []:
                  tid = t.get("tag_id", t.get("id"))
                  if tid is not None:
                      have.add((tid, t.get("value", "")))
              for tag_name, value in want.items():
                  if tag_name not in server_tags:
                      if dry_run:
                          log(f"tags dry-run: would create tag {tag_name}")
                          continue
                      log(f"+ create tag {tag_name}")
                      server_tags[tag_name] = api.add_tag(
                          name=tag_name, color="#5b8def")
                  tid = server_tags[tag_name]["id"]
                  if (tid, value) in have:
                      continue
                  if dry_run:
                      log(f"tags dry-run: would tag {name} "
                          f"{tag_name}={value}")
                      continue
                  log(f"+ tag {name} {tag_name}={value}")
                  api.add_monitor_tag(tid, live[name], value)


      def sync_status_page(api, api_url, page, live, desired, dry_run):
          """Reconcile the single public status page (Nix monitors grouped
          into categories). Other slugs are deleted (authoritative). Never
          uses get_status_page: it crashes on incident parsing in lib
          1.2.1, so existence comes from the list and the save is
          unconditional (idempotent) instead of drift-compared."""
          slug = page["slug"]
          grouped = {}
          for name in page["monitors"]:
              if name in live:
                  grouped.setdefault(
                      desired[name].get("group", "Homelab"), []).append(live[name])
              else:
                  log(f"status page: monitor {name} unknown, skipped")
          ordered = sorted(grouped, key=lambda g: (
              GROUP_ORDER.index(g) if g in GROUP_ORDER else len(GROUP_ORDER), g))
          want_groups = [{"name": g, "weight": pos + 1,
                          "monitorList": [{"id": mid} for mid in grouped[g]]}
                         for pos, g in enumerate(ordered)]
          slugs = {p["slug"]: p for p in api.get_status_pages()}
          if slug not in slugs:
              log(f"+ create status page /status/{slug}")
              if not dry_run:
                  api.add_status_page(slug, page["title"])
                  slugs = {p["slug"]: p for p in api.get_status_pages()}
          if dry_run:
              log(f"dry-run: status page /status/{slug} not saved")
              return
          total = sum(len(ids) for ids in grouped.values())
          log(f"~ save status page /status/{slug} ({total} monitors, "
              f"{len(ordered)} groups)")
          save_status_page_v2(
              api, api_url,
              slug, id=slugs[slug]["id"], title=page["title"],
              description=page["description"], published=True,
              publicGroupList=want_groups)
          for other in api.get_status_pages():
              if other.get("slug") != slug:
                  log(f"- delete status page /status/{other.get('slug')} (not in Nix)")
                  api.delete_status_page(other["slug"])


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
          group = lib.mkOption {
            type = lib.types.str;
            default = "Homelab";
            description = "Status page category (site) for this monitor.";
          };
          tags = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = ''
              Extra monitor tags (name -> value), e.g. { role = "metrics"; }.
              The target address is always tagged automatically. Tags are
              only ever added, never deleted (UI-added tags survive).
            '';
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

    statusPage = {
      enable = lib.mkEnableOption "single public status page with all Nix monitors in one group (other slugs deleted)";

      slug = lib.mkOption {
        type = lib.types.str;
        default = "homelab";
        description = "URL slug (page lives at /status/<slug>).";
      };

      title = lib.mkOption {
        type = lib.types.str;
        default = "Homelab Status";
        description = "Page title.";
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = "Homelab services (declarative monitors, see services.uptime-kuma-sync).";
        description = "Page subtitle.";
      };
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
      # No wantedBy on purpose: starting at switch time races the kuma VM
      # restart (2026-10-03 deploy failed + rolled back on a connect
      # timeout). Convergence comes from the timer (boot + daily) and
      # manual `systemctl start uptime-kuma-sync`.
      wants = ["network-online.target"];
      after = ["network-online.target" "microvm@uptime-kuma.service"];
      # Self-heal transient API login flakes (seen daily 00:00 runs +
      # deploy-time race while the kuma VM boots): retry 3x, then give up
      # until the next timer run (no infinite loop on permanent failure).
      unitConfig = {
        StartLimitIntervalSec = "30m";
        StartLimitBurst = 3;
      };
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "2m";
      };
      script = ''
        set -eu
        exec ${syncScript} \
          --api-url "${cfg.apiUrl}" \
          --username "${cfg.username}" \
          --password-file "${cfg.passwordFile}" \
          --monitors "${desiredJson}" \
          --status-page "${statusPageJson}"
      '';
    };

    systemd.timers.uptime-kuma-sync = {
      description = "Uptime Kuma monitor convergence (boot + daily)";
      wantedBy = ["timers.target"];
      timerConfig = {
        # Boot-delayed so the kuma VM is up (no switch-time race).
        OnBootSec = "10m";
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
          --status-page "${statusPageJson}" \
          --dry-run
      '';
    };
  };
}
