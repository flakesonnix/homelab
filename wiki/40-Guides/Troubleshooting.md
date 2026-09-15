---
aliases: [Troubleshooting, Errors, Debugging]
tags: [guide, nixos]
type: guide
---

# Troubleshooting

[[40-Guides/Guides-MOC|← Guides]]

## Rebuild aborts (exit 4, failed unit)

```bash
systemctl --failed
journalctl -b -p err
```

Known on x270: libvirt TPM without `/dev/tpmrm0` → `virtualisation.libvirtd.enable=mkForce false` (see [[10-Hosts/x270|x270]]). Same `243/CREDENTIALS` can hit mireo: `rm /var/lib/libvirt/secrets/secrets-encryption-key` + reboot (see [[10-Hosts/mireo#libvirt-virt-manager-remote-target-weg-a|mireo libvirt]]).

## deploy-rs: NIX_PATH / nixos-config missing

The custom activate in `flake.nix:474` uses a stub — after the first switch + reboot the `nix-settings.nix` etc. entry should take over. If `dry-activate`/`boot` fail, check the stub path.

## Secrets: sops fails at activation

- Is `/etc/sops/age/keys.txt` present? Mode 600?
- Is `sopsFile` set? (`lucy.secrets.enable` asserts it)
- Edit: `SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/<host>/secrets.yaml`

## Network: VM/printer unreachable

```bash
ip -j addr | jq
ping 10.8.0.1; ping 10.8.0.6
ss -tulpn | grep -E '631|8443|19999'
ssh root@10.8.0.1 'systemctl status microvm@cups; systemctl status dnsmasq'
```

- On 10.8.0.0/24? (Wi-Fi via mireo or Tailscale required)
- dnsmasq `bindsTo` fix active? (`data/hosts/mireo/settings.nix:356-357`)
- cups VM running? → [[40-Guides/Printing|Printing]]

## opencode (Console): `reasoning encrypted_content was not issued to this caller`

`Error from provider (Console): Upstream request failed: [invalid_request_error]
reasoning encrypted_content was not issued to this caller` — repeats on every
continue/retry, often first seen after enabling/disabling NAT66 on mireo or after
a FritzBox reconnect. The NAT66 rule is NOT the bug (verify: `curl -6` bulk/MTU
tests pass) — it only changes which egress IP the Console proxy sees:

- Anthropic encrypted extended-thinking blocks are bound to the caller that issued
  them. The Console proxy routes per egress IP, so a v4 (`2.213.x.x`) ↔ v6
  (`2a02:…`) switch — or a truncated stream during a renumber — makes the replayed
  blocks foreign. Once poisoned, the transcript fails forever; `continue` re-sends
  the same blocks.
- mireo WAN v6 is short-lived and flaps: `ssh lucy@10.8.0.1 'ip -6 addr show
  enp4s0'` shows ~2h lifetimes, `networkctl status enp4s0` shows repeated
  `DHCPv6 lease lost`. Each flap can poison a running session. With NAT66 off the
  x270 has no v6 internet at all, so everything stays on stable IPv4 NAT — that is
  the perceived "only breaks with IPv6 on" correlation.

Fix (no deploy needed): start a FRESH session (`/new` or `/clear`), never
`--continue`/`--resume` the broken one. Re-auth (`opencode auth login`) if 401s
appear. Prevention: don't toggle NAT66 mid-session; expect FritzBox renumbers to
occasionally poison long agent sessions. Details [[10-Hosts/Network|Network]].

Verified 2026-09-14, so you don't chase ghosts:

- Tunnel mireo↔nyagate is HEALTHY (`wg show wg0`: handshake seconds old,
  `ping 10.66.0.1` 0% loss). The `WireGuardPeer ... without PublicKey` journal
  spam was stale deploy churn (3 switches that day: 12:33/14:20/14:31) — on-disk
  `40-wg0.netdev` carries the key, zero warnings since. No fix needed.
- Same churn explains the `DHCPv6 lease lost` flaps: every `switch-to-configuration`
  reconfigures networkd, the DHCPv6 client restarts, egress flaps, sessions poison.
  Avoid redeploying mireo mid-agent-session.
- br0 has no delegated GUA (ULA-only) — PD configured but not landing (likely
  FritzBox/ISP side, 6660 Cable). Check FritzBox GUI (Heimnetz → Netzwerk →
  IPv6: Präfix delegieren) if native LAN GUA is wanted; until then NAT66 is the
  only LAN v6 egress — don't remove it. Update: tcpdump shows a
  solicit→reply→solicit loop (5x in 15s, never reaching request) — FritzBox
  answers but offers nothing usable; all mireo WAN v6 addresses are SLAAC
  (`dynamic mngtmpaddr`, no DHCPv6 client lease file). Decisive GUI check:
  Internet → Online-Monitor → IPv6-Präfix length. If the ISP hands only a /64,
  there is nothing to delegate and PD is permanently impossible — NAT66 stays.
- Caution: `networkctl reconfigure/renew` on enp4s0 flaps v6 egress and poisons
  running agent sessions exactly like a deploy. Only touch WAN DHCPv6 when no
  agent session is active.

## NixFleet :8443 empty / 503

- M1 is mireo-local only (no WS/multi-host yet). `503` = non-local host → expected.
- Are `manifest.json`/`ui.json` committed? (`nix run .#nixfleet-manifest`, CI job on master only)
- `systemctl status nixfleet-api nixfleet-agent`, `journalctl -u nixfleet-api -f`
- Details [[50-NixFleet/Manifest-API|Manifest & API]].

## Audio latency / gaming stutter

See `docs/audio-latency.md` + [[20-Modules/Gaming-Stack|Gaming]] + [[40-Guides/Audio-Latency|Audio latency]]: governor `performance`? power-profiles-daemon off? Using `MANGOHUD=1`, `gamemoderun`?

## Print job stuck

```bash
ssh root@cups lpstat -t
ssh root@cups cancel -a; ssh root@cups lpq
```
