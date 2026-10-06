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
    # so the expectation can never drift from reality.
    # Deliberately WITHOUT connecting: virtiofsd shuts down when its last
    # client disconnects, so a connect-probe (socat) suicides the daemon
    # it checks (all 26 VMs down, 2026-10-06). Instead match bound socket
    # basenames in /proc/net/unix (kernel state: bound = listening; stale
    # files don't show). Same for the supervisor control client: the generated config has
    # no control section for it.
    socks=$(grep -o 'path=[^,]*\.sock' "$dir/current/bin/microvm-run" 2>/dev/null | sed 's/^path=//;s|^.*/||' || true)
    if [ -z "$socks" ]; then
      echo "microvm-wait-virtiofsd@$vm: no virtiofs sockets in runner" >&2
      exit 1
    fi
    # NOTE: only shell builtins + coreutils/findutils/grep/sed/systemd
    # here. The unit PATH is almost empty (microvm.nix forces it) — every
    # external must exist there or the gate fails closed for all VMs at
    # once (seen 2026-10-06).
    stable=0
    i=0
    while [ "$i" -lt 45 ]; do
      i=$((i + 1))
      live=""
      while read -r _ _ _ _ _ _ _ p; do
        live="$live ''${p##*/}"
      done < /proc/net/unix
      ready=1
      for s in $socks; do
        case " $live " in
          *" $s "*) ;;
          *)
            ready=0
            break
            ;;
        esac
      done
      if [ "$ready" = 1 ]; then
        stable=$((stable + 1))
        if [ "$stable" -ge 2 ]; then exit 0; fi
      else
        stable=0
      fi
      sleep 2
    done
    echo "microvm-wait-virtiofsd@$vm: virtiofs sockets never bound" >&2
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
