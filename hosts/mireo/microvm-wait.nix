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
    conf=""
    stable=0
    i=0
    while [ "$i" -lt 45 ]; do
      i=$((i + 1))
      cur=$(systemctl show -p ExecStart "microvm-virtiofsd@$vm" 2>/dev/null | grep -o '/nix/store/[^ ]*-virtiofsd-supervisord.conf' | head -1 || true)
      if [ -n "$cur" ]; then conf="$cur"; fi
      if [ -n "$conf" ] && out=$(${pkgs.python3Packages.supervisor}/bin/supervisorctl -c "$conf" status 2>/dev/null) && [ -n "$out" ] && ! printf '%s\n' "$out" | grep -v RUNNING | grep -q .; then
        stable=$((stable + 1))
        if [ "$stable" -ge 2 ]; then exit 0; fi
      else
        stable=0
      fi
      sleep 2
    done
    echo "microvm-wait-virtiofsd@$vm: virtiofsd never settled" >&2
    exit 1
  '';
in {
  # As drop-ins (not replacements): microvm.nix owns the instance units,
  # we only append the pre-start gate. Matches its own overrideStrategy.
  systemd.services = lib.mapAttrs' (vmName: _:
    lib.nameValuePair "microvm@${vmName}" {
      overrideStrategy = "asDropin";
      serviceConfig.ExecStartPre = ["${waitForVirtiofsd} ${vmName}"];
    }) config.microvm.vms;
}
