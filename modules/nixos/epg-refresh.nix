/*
* Aktueller XMLTV-EPG für Jellyfin (iptv-org/epg, host-seitig)
*
* Baut aus iptv-org/epg-Quellen einen Guide, dessen `channel id`s exakt zu
* den `tvg-id`s der M3Us auf der Jellyfin-MicroVM passen, und schiebt ihn
* per SSH auf die VM. Läuft auf DIESEM Host (nicht in der VM): Repo-Clone,
* npm und SSH-Key leben hier, das Davies-`/media` der VM ist read-only.
*
* Ablauf pro Lauf (alles geloggt, `journalctl -u epg-refresh`):
*   1. iptv-org/epg frisch per `git clone --depth 1` (kein Snapshot!),
*      `npm ci` nur bei geändertem package-lock.
*   2. Drift-Check: M3U-`tvg-id`s auf der VM vs. ./channels.xml (nur WARN).
*   3. `npm run grab` (days/maxConnections konfigurierbar).
*   4. ANTI-STALE-GATE: späteste Sendung >= jetzt+20h, früheste >= jetzt-48h,
*      >= 1000 Programme, Pflichtsender (RTL/ProSieben/VOX/ZDF/DasErste)
*      je >= 1 Sendung — sonst ABBRUCH, kein Push (schützt vor
*      Juli-2026-Feed wie freeepg.xml).
*   5. Push per scp nach remoteGuidePath (jellyfin:jellyfin, 0644).
*   6. Jellyfin-XMLTV-Cache auf der VM löschen
*      (/var/cache/jellyfin/xmltv/*.xml — Key ist die Provider-ID, sonst
*      liest Jellyfin nach Pfadwechsel still die ALTE Datei, 0 Programme,
*      keine Fehlermeldung!).
*   7. RefreshGuide per Jellyfin-API triggern (Token via LoadCredential,
*      Task-ID wird per API gesucht, nicht hartcodiert).
*   8. Verifikation (best-effort): früheste/späteste Sendung + Total via API.
*
* Secrets: NUR der Jellyfin-API-Token, via sops
*   (hosts/<host>/secrets.yaml: `jellyfin/epg-api-token`, Key auf dem
*   Jellyfin-Host als `epg-setup` angelegt). SSH läuft über den User-Key
*   (BatchMode, StrictHostKeyChecking bleibt an).
*
* Debugging: systemctl status epg-refresh; manuell: systemctl start epg-refresh
* Timer: täglich + Persistent (holt Boot-Lücken nach).
*/
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.epg-refresh;

  nodejs = pkgs.nodejs;
  channelsFile = ./epg-refresh/channels.xml;

  refreshScript = pkgs.writeShellScript "epg-refresh-run" ''
    set -euo pipefail
    PATH=${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.curl pkgs.gawk pkgs.git pkgs.gnugrep pkgs.gnused pkgs.jq nodejs pkgs.openssh]}:$PATH

    log() { echo "epg-refresh: $*" >&2; }
    die() { log "FATAL: $*"; exit 1; }

    STATE="''${STATE_DIRECTORY:-/var/lib/epg-refresh}"
    SRC="$STATE/epg-src"
    GUIDE="$STATE/guide.xml"
    TOKEN_FILE="$CREDENTIALS_DIRECTORY/jellyfin-api-token"

    [ -s "$TOKEN_FILE" ] || die "API-Token fehlt ($TOKEN_FILE). sops-Secret prüfen."
    [ -f "${channelsFile}" ] || die "channels.xml fehlt im Store."

    # --- 1. Quelle frisch holen ---
    if [ -d "$SRC/.git" ]; then
      git -C "$SRC" fetch --depth 1 origin master 2>&1 | tail -n 2 || die "git fetch failed"
      git -C "$SRC" reset --hard origin/master 2>&1 | tail -n 1
    else
      rm -rf "$SRC"
      git clone --depth 1 --branch master https://github.com/iptv-org/epg.git "$SRC" 2>&1 | tail -n 2 || die "git clone failed"
    fi
    REV=$(git -C "$SRC" rev-parse --short HEAD)
    log "epg-Quellstand: $REV ($(git -C "$SRC" log -1 --format=%ci))"

    if [ ! -d "$SRC/node_modules" ] || ! cmp -s "$SRC/package-lock.json" "$STATE/package-lock.json"; then
      log "npm ci läuft (deps installieren)…"
      (cd "$SRC" && npm ci --no-audit --no-fund 2>&1 | tail -n 3) || die "npm ci failed"
      cp "$SRC/package-lock.json" "$STATE/package-lock.json"
    fi

    SSH="ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes ${cfg.remoteUser}@${cfg.epgHost}"
    M3US="${cfg.m3uPaths}"
    SSH_ERR="$STATE/ssh.err"

    # --- 2. Drift-Check (M3U auf VM vs. channels.xml) ---
    # SSH separat vorab prüfen: sonst verschlucken pipefail/2>/dev/null die
    # eigentliche Ursache (z.B. "Host key verification failed" bei fehlendem
    # known_hosts-Eintrag) und im Journal steht nur "M3Us nicht lesbar".
    if ! $SSH true 2>"$SSH_ERR"; then
      log "SSH-Details (${cfg.remoteUser}@${cfg.epgHost}):"
      cat "$SSH_ERR" >&2 || true
      die "Jellyfin-VM per SSH nicht erreichbar — known_hosts-Key? User-Key autorisiert? VM down?"
    fi
    M3U_IDS=$($SSH "grep -h '^#EXTINF' ''${M3US}" 2>"$SSH_ERR" | ${pkgs.gnused}/bin/sed -n 's/.*tvg-id="\([^"]*\)".*/\1/p' | sort -u) || {
      log "SSH-Details:"
      cat "$SSH_ERR" >&2 || true
      die "M3Us auf VM nicht lesbar (Pfade prüfen: ${cfg.m3uPaths})"
    }
    KNOWN_IDS=$(grep -o 'xmltv_id="[^"]*"' "${channelsFile}" | sed 's/xmltv_id="//;s/"//' | sort -u)
    DRIFT=$(comm -23 <(echo "$M3U_IDS") <(echo "$KNOWN_IDS") || true)
    if [ -n "$DRIFT" ]; then
      log "WARN: M3U-IDs ohne Scraper (kein EPG dafür): $(echo "$DRIFT" | tr '\n' ' ')"
    fi
    log "M3U-IDs: $(echo "$M3U_IDS" | wc -l), davon mit Scraper: $(comm -12 <(echo "$M3U_IDS") <(echo "$KNOWN_IDS") | wc -l)"

    # --- 3. Grab ---
    (cd "$SRC" && npm run grab --- --channels="${channelsFile}" --output="$GUIDE" --days=${toString cfg.days} --maxConnections=${toString cfg.maxConnections} --timeout=30000 2>&1 | tail -n 3) || die "grab failed"
    [ -s "$GUIDE" ] || die "guide.xml leer/fehlt"

    # --- 4. ANTI-STALE-GATE ---
    NOW=$(date -u +%Y%m%d%H%M%S)
    MIN_LATEST=$(date -u -d "+20 hours" +%Y%m%d%H%M%S)
    MAX_EARLIEST=$(date -u -d "-48 hours" +%Y%m%d%H%M%S)
    STATS=$(grep -o '<programme[^>]*start="[0-9]*' "$GUIDE" | grep -o '[0-9]*$' | sort -n | awk 'NR==1{e=$1} {l=$1; n++} END{print e" "l" "n}')
    read -r EARLIEST LATEST TOTAL <<< "$STATS"
    log "Guide: $TOTAL Programme, $EARLIEST .. $LATEST (jetzt $NOW)"
    [ "$TOTAL" -ge 1000 ] || die "zu wenig Programme ($TOTAL) — kein Push"
    [ "$LATEST" \> "$MIN_LATEST" ] || die "Guide veraltet (späteste Sendung $LATEST < $MIN_LATEST) — kein Push"
    [ "$EARLIEST" \< "$NOW" ] && [ "$EARLIEST" \> "$MAX_EARLIEST" ] || die "Guide-Zeitraum unplausibel ($EARLIEST) — kein Push"
    for must in RTL.de ProSieben.de VOX.de ZDF.de DasErste.de; do
      N=$(grep -c "channel=\"$must\"" "$GUIDE" || true)
      [ "$N" -ge 1 ] || die "Pflichtsender ohne Programme: $must — kein Push"
    done

    # --- 5. Push ---
    scp -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes "$GUIDE" "${cfg.remoteUser}@${cfg.epgHost}:${cfg.remoteGuidePath}" || die "scp failed"
    $SSH "chown jellyfin:jellyfin '${cfg.remoteGuidePath}' && chmod 644 '${cfg.remoteGuidePath}'" || die "remote chown failed"
    log "gepusht: ${cfg.remoteGuidePath}"

    # --- 6. Jellyfin XMLTV-Cache busten (Pfadwechsel greift sonst NICHT) ---
    $SSH "rm -f /var/cache/jellyfin/xmltv/*.xml" || die "cache-bust failed"

    # --- 7. Refresh triggern ---
    API="${cfg.jellyfinUrl}"
    TASK=$(curl -s -m 15 -H "X-Emby-Token: $(cat "$TOKEN_FILE")" "$API/ScheduledTasks" | ${pkgs.jq}/bin/jq -r '.[] | select(.Key=="RefreshGuide") | .Id')
    [ -n "$TASK" ] && [ "$TASK" != "null" ] || die "RefreshGuide-Task nicht gefunden"
    curl -s -m 15 -o /dev/null -w "%{http_code}" -X POST -H "X-Emby-Token: $(cat "$TOKEN_FILE")" "$API/ScheduledTasks/Running/$TASK" | grep -q 204 || die "refresh trigger failed"
    log "RefreshGuide getriggert ($TASK), warte auf Abschluss…"
    for _ in $(seq 1 30); do
      ST=$(curl -s -m 10 -H "X-Emby-Token: $(cat "$TOKEN_FILE")" "$API/ScheduledTasks" | ${pkgs.jq}/bin/jq -r '.[] | select(.Key=="RefreshGuide") | .State')
      [ "$ST" = "Idle" ] && break
      sleep 20
    done
    [ "$ST" = "Idle" ] || log "WARN: Refresh nach 10min noch $ST (läuft evtl. weiter)"

    # --- 8. Verifikation (best-effort) ---
    SUM=$(curl -s -m 30 -H "X-Emby-Token: $(cat "$TOKEN_FILE")" "$API/LiveTv/Programs?limit=20000&fields=ChannelInfo" | ${pkgs.jq}/bin/jq -r '[.Items[]] | "\(length) Programme"')
    log "Jellyfin meldet: $SUM"
    log "fertig (Quelle $REV)"
  '';
in {
  options.services.epg-refresh = {
    enable = lib.mkEnableOption "täglicher XMLTV-Guide für Jellyfin (iptv-org/epg, host-seitig gebaut)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "lucy";
      description = "Lokaler User für Grab + SSH (braucht SSH-Key zum Jellyfin-Host).";
    };

    epgHost = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin.home.arpa";
      description = "Jellyfin-MicroVM (SSH-Ziel).";
    };

    remoteUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "SSH-User auf der MicroVM.";
    };

    jellyfinUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://jellyfin.home.arpa:8096";
      description = "Jellyfin-API-Basis (vom ausführenden Host erreichbar).";
    };

    apiTokenFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Absoluter Laufzeitpfad zum Jellyfin-API-Token (nur der Pfad landet
        im Store, nie das Secret):
          sops.secrets."jellyfin/epg-api-token" = { owner = "lucy"; };
          services.epg-refresh.apiTokenFile = "/run/secrets/jellyfin/epg-api-token";
      '';
    };

    m3uPaths = lib.mkOption {
      type = lib.types.str;
      default = "/media/TV/tvsd.m3u /media/TV/tvhd.m3u";
      description = "M3U-Pfade AUF der MicroVM (nur gelesen, Drift-Check).";
    };

    remoteGuidePath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyfin/guide.xml";
      description = "Zielpfad des Guides AUF der MicroVM (muss schreibbar + von Jellyfin lesbar sein; /media ist dort read-only). Muss zum Pfad im Jellyfin-ListingProvider passen.";
    };

    days = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "EPG-Tage pro Grab.";
    };

    maxConnections = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Parallele Grab-Requests.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd-OnCalendar für den Timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.apiTokenFile != "" && lib.hasPrefix "/" cfg.apiTokenFile;
        message = ''services.epg-refresh: apiTokenFile muss ein absoluter Laufzeitpfad sein (z.B. "/run/secrets/jellyfin/epg-api-token").'';
      }
      {
        assertion = cfg.epgHost != "";
        message = "services.epg-refresh: epgHost darf nicht leer sein.";
      }
    ];

    sops.secrets."jellyfin/epg-api-token" = lib.mkIf (cfg.apiTokenFile == "/run/secrets/jellyfin/epg-api-token") {
      # LoadCredential liest als root — Owner root genügt; zusätzlich eng:
      mode = "0400";
    };

    systemd.services.epg-refresh = {
      description = "XMLTV-Guide bauen (iptv-org/epg) und auf Jellyfin schieben";
      # No wantedBy on purpose: starting at switch time races the jellyfin
      # VM restart (2026-10-05: connection refused mid-deploy failed the
      # whole x270 switch + revoked all nodes). Timer-driven only; a failed
      # run retries at the next timer tick, never blocks deploys.
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
        StateDirectory = "epg-refresh";
        StateDirectoryMode = "0750";
        LoadCredential = "jellyfin-api-token:${cfg.apiTokenFile}";
        TimeoutStartSec = "30min";
      };
      script = ''
        exec ${refreshScript}
      '';
    };

    systemd.timers.epg-refresh = {
      description = "Täglicher XMLTV-Guide für Jellyfin";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
      };
    };
  };
}
