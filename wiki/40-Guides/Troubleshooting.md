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

Known on x270: libvirt TPM without `/dev/tpmrm0` → `virtualisation.libvirtd.enable=mkForce false` (see [[10-Hosts/x270|x270]]).

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
- dnsmasq `bindsTo` fix active? (`data/hosts/mireo/settings.nix:230`)
- cups VM running? → [[40-Guides/Printing|Printing]]

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
