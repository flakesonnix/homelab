# Audio Latency Troubleshooting

## Ubuntu 24.04 LTS

PipeWire is default. Need rtkit + config tweaks:

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

Reboot after adding user to `audio` group.

## NixOS (x270/gaming role)

Declarative via gaming role. Chain:

`data/roles/gaming.nix` → `data/presets/gaming-performance.nix` → `modules/nixos/gaming/{common,audio,performance,sysctl}.nix`

| Setting | Value |
|---------|-------|
| PipeWire quantum | 64 |
| CPU governor | performance |
| rtkit | enabled via `security.rtkit.enable` |
| sched_migration_cost_ns | 5000000 |
| tcp_low_latency | 1 |
| net.core.{r,w}mem_max | 16777216 |

## Non-NixOS manual config

### PipeWire low-latency

`~/.config/pipewire/pipewire.conf.d/latency.conf`:

```
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 256
    default.clock.min-quantum = 128
    default.clock.max-quantum = 1024
}
```

Restart: `systemctl --user restart pipewire pipewire-pulse`

### PulseAudio (legacy)

`/etc/pulse/daemon.conf`:

```
default-fragments = 2
default-fragment-size-msec = 5
```

Restart: `pulseaudio -k`

### CPU governor

Check: `cpupower frequency-info -g`
Fix: `sudo cpupower frequency-set -g performance`

### Realtime priority

`/etc/security/limits.d/audio.conf`:

```
@audio - rtprio 95
@audio - memlock 4194304
```

Add user to `audio` group. Reboot.

### USB audio quirks

- Use USB 2.0 ports, not USB 3.0
- `echo 0 | sudo tee /sys/module/snd_usb_audio/parameters/vendor_specific`
