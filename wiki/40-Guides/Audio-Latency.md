---
aliases: [Audio latency, PipeWire, Latency]
tags: [guide, nixos]
type: guide
---

# Audio latency

[[40-Guides/Guides-MOC|← Guides]] · [[20-Modules/Gaming-Stack|Gaming stack]] · Source `docs/audio-latency.md`.

## NixOS x270 (declarative, gaming role)

Chain: `data/roles/gaming.nix` → `data/presets/gaming-performance.nix` → `modules/nixos/gaming/{common,audio,performance,sysctl}.nix`.

| Setting | Value |
|---------|-------|
| PipeWire quantum | 64 |
| CPU governor | performance |
| rtkit | via `security.rtkit.enable` |
| sched_migration_cost_ns | 5000000 |
| tcp_low_latency | 1 |
| net.core.{r,w}mem_max | 16777216 |

Nothing to do manually — just check that `data/hosts/x270/roles.nix` contains `gaming`.

## Ubuntu 24.04 (manual)

```bash
sudo apt install rtkit linux-tools-common linux-tools-$(uname -r)
sudo cpupower frequency-set -g performance
sudo usermod -aG audio $USER
```

`/etc/pipewire/pipewire.conf.d/latency.conf`:

```
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 64
    default.clock.min-quantum = 64
    default.clock.max-quantum = 512
}
```

```bash
systemctl --user restart pipewire pipewire-pulse
```

Reboot after joining the `audio` group.

## Generic (non-NixOS)

`~/.config/pipewire/pipewire.conf.d/latency.conf` (quantum 256, min 128, max 1024), then `systemctl --user restart pipewire pipewire-pulse`.

Legacy PulseAudio `/etc/pulse/daemon.conf`: `default-fragments=2`, `default-fragment-size-msec=5`, then `pulseaudio -k`.

Realtime `/etc/security/limits.d/audio.conf`:

```
@audio - rtprio 95
@audio - memlock 4194304
```

USB tip: prefer USB 2.0 ports over 3.0, optionally `echo 0 | sudo tee /sys/module/snd_usb_audio/parameters/vendor_specific`.
Check: `cpupower frequency-info -g`.
