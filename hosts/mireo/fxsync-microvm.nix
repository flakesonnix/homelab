# Firefox Sync storage server (microVM on br0, syncstorage-rs + tokenserver).
# Self-hosted Mozilla Sync in singleNode mode: Firefox clients set
# identity.sync.tokenserver.uri to https://fxsync.home.arpa/1.0/sync/1.5
# (desktop via about:config, Android via the sync-debug menu; served via
# the host Caddy vhost; trust its internal public CA first, see docs/hosts.md).
# The FxA account itself stays at Mozilla - only data storage + token
# issuance run here.
# Secrets (SYNC_MASTER_SECRET + metrics hash secret) are generated in-guest
# on first boot into the data volume — never in the store, no host sops
# needed (hence "fxsync" in secretlessVMs in tests/default.nix).
{pkgs, ...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "fxsync";
      ip = (import ./vm-ips.nix).fxsync;
      mem = 1024;
      vcpu = 1;
      tcpPorts = [22];
      volumes = [
        {
          image = "fxsync-data.img";
          mountPoint = "/var/lib/firefox-syncserver";
          size = 2048;
          user = "mysql";
          group = "mysql";
        }
      ];
      config = {
        networking.firewall.extraCommands = ''
          iptables -w -A nixos-fw -p tcp -s 10.8.0.1 --dport 5000 -j nixos-fw-accept
          ip6tables -w -A nixos-fw -p tcp -s fd00:cafe:1::1 --dport 5000 -j nixos-fw-accept
        '';
        services.mysql = {
          enable = true;
          package = pkgs.mariadb;
          dataDir = "/var/lib/firefox-syncserver/mysql";
        };
        # First-boot secret generation (idempotent, fail-open never:
        # without this file the syncserver unit refuses to start, so any
        # error here must abort loudly instead).
        systemd.services.firefox-syncserver-secrets-setup = {
          description = "Generate Firefox Sync secrets on first boot";
          before = ["firefox-syncserver.service"];
          requiredBy = ["firefox-syncserver.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            dir=/var/lib/firefox-syncserver
            mkdir -p "$dir"
            if [ ! -f "$dir/secrets.env" ]; then
              umask 077
              master=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
              metrics=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
              printf 'SYNC_MASTER_SECRET=%s\nSYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET=%s\n' \
                "$master" "$metrics" > "$dir/secrets.env"
              chmod 0400 "$dir/secrets.env"
            fi
          '';
        };
        services.firefox-syncserver = {
          enable = true;
          # Upstream default binds localhost — Caddy (host) proxies to
          # the LAN IP; the guest firewall permits port 5000 only from mireo.
          # Upstream breakage (nixpkgs 624af66, syncstorage-rs 0.21.1):
          # PyO3 0.24.2 caps Python at 3.13 but builds against 3.14
          # (stable ABI per the error's own suggestion), and newer rustc
          # denies diesel 2.3's ambiguous `dsl::max` glob re-export
          # (future-incompat, not allow-able from downstream — the only
          # public path goes through diesel::dsl). Cap lints workspace-
          # wide like cargo does for non-local deps.
          package = pkgs.syncstorage-rs.overrideAttrs (old: {
            PYO3_USE_ABI3_FORWARD_COMPATIBILITY = "1";
            RUSTFLAGS = "--cap-lints=warn";
            postPatch =
              (old.postPatch or "")
              + ''
                sed -i '1i #![allow(ambiguous_glob_imports)]' syncstorage-mysql/src/db/db_impl.rs
              '';
          });
          secrets = "/var/lib/firefox-syncserver/secrets.env";
          settings.host = "0.0.0.0";
          singleNode = {
            enable = true;
            hostname = "fxsync.home.arpa";
            url = "https://fxsync.home.arpa";
          };
        };
      };
    })
  ];
}
