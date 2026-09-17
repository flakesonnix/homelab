# LDAP directory for the homelab (microVM on br0, lldap).
# Identity DATA source (users/groups for Pocket ID OIDC + future RADIUS),
# not an auth platform. Base DN dc=home,dc=arpa matches home.arpa.
# Admin password via host sops (shared read-only into the guest — same
# pattern as voice passwordFiles, only the path enters the store).
# Users below are declarative (GraphQL seed, idempotent create/update +
# password set; UI edits get overwritten on next boot). Passwords come
# from staged sops files (lldap/users/<id>); missing file = user without
# password change, never a failure.
# Volume holds sqlite DB + auto-generated JWT secret. lldap runs
# DynamicUser upstream, which fails on a mounted volume (same exit 238
# trap as uptime-kuma) — static system user + forced off, like there.
{
  lib,
  pkgs,
  ...
}: let
  # Declarative users. email/displayName/firstName are LLDAP-visible;
  # passwordFile is staged from host sops (see lldap-secrets-setup).
  seedUsers = [
    {
      id = "lucy";
      email = "lucy@home.arpa";
      displayName = "Lucy";
      firstName = "Lucy";
      lastName = "";
      passwordFile = "/run/lldap/users/lucy";
    }
  ];
  seedJson = pkgs.writeText "lldap-seed-users.json" (builtins.toJSON seedUsers);
in {
  imports = [
    (import ./mk-microvm.nix {
      name = "lldap";
      ip = (import ./vm-ips.nix).lldap;
      mem = 512;
      vcpu = 1;
      tcpPorts = [22 3890 17170];
      volumes = [
        {
          image = "lldap-data.img";
          mountPoint = "/var/lib/lldap";
          size = 512;
          user = "lldap";
          group = "lldap";
        }
      ];
      shares = [
        {
          tag = "lldap-secrets";
          source = "/run/secrets/lldap";
          mountPoint = "/run/secrets/lldap";
          readOnly = true;
        }
      ];
      config = {
        users.users.lldap = {
          isSystemUser = true;
          group = "lldap";
        };
        users.groups.lldap = {};
        systemd.services.lldap.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "lldap";
        };
        # Stage ALL host-shared secrets into guest tmpfs (admin password
        # plus per-user files): direct reads from the virtiofs share fail
        # inside lldap with EOPNOTSUPP (seen 2026-09-17), plain tools like
        # cat work — quirk class avoided entirely by staging before start.
        systemd.services.lldap-secrets-setup = {
          description = "Stage LLDAP secrets from virtiofs share into tmpfs";
          before = ["lldap.service"];
          requiredBy = ["lldap.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            mkdir -p /run/lldap
            cd /run/secrets/lldap
            find . -type f -print0 | while IFS= read -r -d "" f; do
              install -D -o lldap -g lldap -m0400 "$f" "/run/lldap/$f"
            done
          '';
        };
        services.lldap = {
          enable = true;
          silenceForceUserPassResetWarning = true;
          settings = {
            ldap_base_dn = "dc=home,dc=arpa";
            ldap_user_dn = "admin";
            ldap_user_email = "admin@home.arpa";
            ldap_user_pass_file = "/run/lldap/admin-password";
            force_ldap_user_pass_reset = false;
            http_url = "http://lldap.home.arpa";
          };
        };
        # Declarative user seed via GraphQL (subset of upstream
        # bootstrap.sh: create/update + password, no avatars/schemas, no
        # deletes). Idempotent every boot. NEVER fails the unit: seed
        # problems must not take down the directory (nor the host deploy
        # watching it) — loud ERROR log instead, fixed forward.
        systemd.services.lldap-seed = {
          description = "Seed declarative LLDAP users (idempotent)";
          after = ["lldap.service" "lldap-secrets-setup.service"];
          requires = ["lldap.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            User = "lldap";
            Group = "lldap";
          };
          path = with pkgs; [curl jq];
          script = ''
            set -u
            say() { echo "lldap-seed: $1"; }
            err() { echo "lldap-seed: ERROR: $1" >&2; }
            api() { curl -sf --max-time 15 "$@"; }

            url=http://localhost:17170
            for i in $(seq 1 24); do
              if api "$url/" -o /dev/null; then break; fi
              if [ "$i" = 24 ]; then err "lldap not ready after 2min"; exit 0; fi
              sleep 5
            done

            admin_pw=$(cat /run/lldap/admin-password)
            token=$(jq -n --arg u admin --arg p "$admin_pw" \
              '{username: $u, password: $p}' \
              | api -X POST "$url/auth/simple/login" \
                -H "Content-Type: application/json" -d @- \
              | jq -r .token)
            unset admin_pw
            if [ -z "$token" ] || [ "$token" = "null" ]; then
              err "admin login failed"
              exit 0
            fi

            tmp=$(mktemp -d)
            trap 'rm -rf "$tmp"' EXIT
            jq -n '{query: "query L($filters: RequestFilter){users(filters: $filters){id}}", operationName: "L", variables: {filters: null}}' \
              > "$tmp/list.json"
            jq -c '.[]' ${seedJson} | while read -r user; do
              id=$(jq -r .id <<<"$user")
              # NOTE: never log $user (may carry secrets in future fields).
              exists=$(api -X POST "$url/api/graphql" \
                  -H "Authorization: Bearer $token" \
                  -H "Content-Type: application/json" \
                  -d @"$tmp/list.json" \
                | jq --arg id "$id" '[.data.users[].id] | index($id) != null')
              if [ "$exists" = "true" ]; then op=UpdateUser; res=ok;
              else op=CreateUser; res="id"; fi
              jq -n --argjson u "$(jq -c '{id,email,displayName,firstName,lastName}' <<<"$user")" \
                  --arg op "$op" --arg res "$res" \
                  '{query: "mutation M($user: \($op)Input!) {\($op)(user: $user) {\($res)}}", operationName: "M", variables: {user: $u}}' \
                > "$tmp/mut.json"
              out=$(api -X POST "$url/api/graphql" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" \
                -d @"$tmp/mut.json") || { err "user $id mutation transport failed"; continue; }
              msg=$(jq -r '.errors | if . == null then empty else .[].message end' <<<"$out")
              if [ -n "$msg" ]; then err "user $id: $msg"; continue; fi
              say "user $id ensured"
              pwfile=$(jq -r .passwordFile <<<"$user")
              if [ -r "$pwfile" ]; then
                if LLDAP_USER_PASSWORD="$(cat "$pwfile")" ${pkgs.lldap}/bin/lldap_set_password \
                    --base-url "$url" --token "$token" --username "$id" >/dev/null 2>&1; then
                  say "user $id password set"
                else
                  err "user $id password set failed"
                fi
              else
                say "user $id has no password file, skipped"
              fi
            done
            exit 0
          '';
        };
      };
    })
  ];
}
