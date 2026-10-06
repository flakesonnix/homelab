# Gate every microVM start on settled virtiofsd.
#
# Background (2026-10-05): microvm-run dies instantly when a virtiofs
# socket is missing, and virtiofsd sub-daemons need ~seconds to spawn
# after a restart (new shares!). QEMU winning that race fails the whole
# switch (+ rollback). Waiting here converts flakes into converges;
# genuinely broken configs still fail loudly after the timeout.
{
  config,
  lib,
  pkgs,
  ...
}: let
  waitForVirtiofsd = pkgs.writeShellScript "microvm-wait-virtiofsd" ''
    set -eu
    vm="$1"
    dir="/var/lib/microvms/$vm"
    # Expected sockets, derived from the SAME runner QEMU is about to use,
    # so the expectation can never drift from reality. (Polling the
    # supervisor control socket is impossible: the generated config has
    # no control section for it.)
    socks=$(grep -o 'path=[^,]*\.sock' "$dir/current/bin/microvm-run" 2>/dev/null | sed 's/^path=//' || true)
    if [ -z "$socks" ]; then
      echo "microvm-wait-virtiofsd@$vm: no virtiofs sockets in runner" >&2
      exit 1
    fi
    stable=0
    i=0
    while [ "$i" -lt 45 ]; do
      i=$((i + 1))
      ready=1
      for s in $socks; do
        case "$s" in
          /*) sock="$s" ;;
          *) sock="$dir/$s" ;;
        esac
        if ! timeout 1 ${pkgs.socat}/bin/socat - "UNIX-CONNECT:$sock" </dev/null >/dev/null 2>&1; then
          ready=0
          break
        fi
      done
      if [ "$ready" = 1 ]; then
        stable=$((stable + 1))
        if [ "$stable" -ge 2 ]; then exit 0; fi
      else
        stable=0
      fi
      sleep 2
    done
    echo "microvm-wait-virtiofsd@$vm: virtiofs sockets never came up" >&2
    exit 1
  '';
in {
  # As drop-ins (not replacements): microvm.nix owns the instance units,
  # we only append the pre-start gate. Matches its own overrideStrategy.
  systemd.services = lib.mapAttrs' (vmName: _:
    lib.nameValuePair "microvm@${vmName}" {
      overrideStrategy = "asDropin";
      serviceConfig.ExecStartPre = ["${waitForVirtiofsd} ${vmName}"];
    })
  config.microvm.vms;
}
