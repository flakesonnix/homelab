# Modules

All custom modules live in `modules/`. They are not auto-imported; hosts and profiles explicitly list the ones they need in `flake.nix`.

---

## NixOS Modules (`modules/nixos/`)

### `base.nix`

Options namespace: `lucy.base.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable base configuration |
| `isServer` | bool | false | Server mode: disables libvirtd, virt-manager, X11 forwarding |
| `timezone` | str | `"Europe/Berlin"` | System timezone |
| `locale` | str | `"en_US.UTF-8"` | Default locale (LC_* set to de_DE) |
| `sshKey` | str | required | SSH public key added to lucy + root authorized_keys |
| `sshKeyComment` | str | `"lucy@dotfiles"` | Comment appended to authorized key |
| `initrdSshPort` | int | 2222 | Port for initrd SSH unlock |

When enabled: OpenSSH (no password auth), sudo, libvirtd (non-server), firewall (TCP 22/24800, 5555-5585), initrd SSH with host key at `/etc/secrets/initrd/ssh_host_ed25519_key`, `trusted-users = ["root" "lucy"]`.

---

### `network.nix`

Options namespace: `networking.staticIP.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable static IP (disables NetworkManager and DHCP) |
| `address` | str | required | Static IPv4 address |
| `prefixLength` | int | 24 | Subnet prefix length |
| `gateway` | str | required | Default gateway |
| `dns` | list of str | `["1.1.1.1" "8.8.8.8"]` | DNS servers |
| `interface` | str | required | Network interface name |

---

### `nvidia.nix`

Options namespace: `lucy.nvidia.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable NVIDIA config |
| `modesetting` | bool | true | Kernel modesetting |
| `prime` | bool | false | Enable PRIME offload (fine-grained power management) |

When enabled: `hardware.graphics` with 32-bit, production driver package, `NVreg_PreserveVideoMemoryAllocations=1`, `mem_sleep_default=s2idle`, logind suspend/lid handling, and a `nvidia-loader` oneshot systemd service that lazy-loads kernel modules after `graphical.target` (skips if built modules don't match running kernel — safe across `nixos-rebuild switch` without reboot).

---

### `nvidia-resume.nix`

No options. Fixes NVIDIA suspend/resume by writing ACPI quirks. Imported alongside `nvidia.nix` on omen.

---

### `niri.nix`

Options namespace: `niri.users`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `niri.users` | list of str | `[]` | Home Manager users that get Niri host integration |

When `niri.users` is non-empty: enables `programs.niri`. When `programs.niri.enable` is true: installs `xwayland-satellite`, configures `xdg-desktop-portal-gnome` restart policy, enables gvfs/udisks2, sets `NIXOS_OZONE_WL=1`, and configures greetd with tuigreet (remember session, user menu, asterisks).

---

### `gaming.nix`

Aggregate import. Pulls in:

- `gaming/common.nix` — baseline gaming config
- `gaming/steam.nix` — `lucy.gaming.steam.*`: Steam, GameMode, Gamescope, MangoHud
- `gaming/audio.nix` — audio tweaks for gaming
- `gaming/performance.nix` — `lucy.gaming.performance.*`: CPU governor, disable power profiles daemon; `lucy.gaming.gamescope.capSysNice`
- `gaming/sysctl.nix` — `lucy.gaming.sysctl.*`: network low-latency sysctl knobs
- `gaming/systemd.nix` — systemd unit tweaks

Activated via presets: `gaming-base` → `lucy.gaming.enable`, `gaming-steam` → steam/gamemode/gamescope/mangohud, `gaming-performance` → performance tuning.

---

### `sops.nix`

Options namespace: `lucy.secrets.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable sops-nix |
| `sopsFile` | path or null | null | Path to encrypted secrets YAML (required when enabled) |
| `ageKeyPath` | path | `/etc/sops/age/keys.txt` | Age private key path |

Thin wrapper around sops-nix that enforces `sopsFile != null` via assertion.

---

### `pipebert.nix`

A network audio receiver. Options namespace: `lucy.pipebert.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Pipebert |
| `user` | str | `"lucy"` | User owning lingering services |
| `hostName` | str | `"pipebert"` | Fallback hostname |
| `domain` | str or null | null | Optional domain for vhosts |
| `name` | str | `"Pipebert"` | AirPlay/sink advertised name |
| `mediaDir` | str | `"/home/lucy/Music"` | Mopidy local music dir |
| `allowedCidrs` | list of str | `[]` | CIDRs for restricted firewall (empty = open to all) |
| `openFirewall` | bool | false | Open service ports |
| `airplay.enable` | bool | true | Shairport Sync + nqptp (AirPlay 1 + 2) |
| `mopidy.enable` | bool | true | Mopidy with Iris/MPD/YouTube |
| `mopidy.extensionPackages` | list | `[]` | Extra Mopidy extensions |
| `mopidy.extraConfigFiles` | list | `[]` | Extra Mopidy config files (for secrets) |
| `mopidy.extraSettings` | attrs | `{}` | Mopidy settings merged over defaults |
| `ledfx.enable` | bool | false | LEDfx as user service |
| `web.enable` | bool | false | Nginx landing page + reverse proxies |
| `sinkNode.enableRename` | bool | false | Rename physical PipeWire sink node |
| `sinkNode.nodeName` | str | `""` | PipeWire node name to rename |
| `sinkNode.description` | str | `"Pipebert Audio Streaming"` | Renamed sink description |
| `usbDevice.enableReload` | bool | false | Cycle USB audio device after PipeWire starts |
| `usbDevice.vendorId` | str | `""` | USB vendor ID |
| `usbDevice.productId` | str | `""` | USB product ID |

Services started: PipeWire (RTP SAP receive, PulseAudio TCP on 4713, zeroconf publish), Avahi (mDNS), Mopidy (optional), Shairport Sync user service (optional), nqptp system service (optional), LEDfx user service (optional), Nginx (optional).

Firewall ports (when `openFirewall = true`): 4713/tcp (Pulse), 6600/tcp (MPD), 5000/7000/tcp + 6001-6011/udp + 49152-60999/udp (AirPlay), 5353/udp (mDNS), 9875/udp (RTP), 319-320/udp (PTP). When `allowedCidrs != []`, uses nftables source-restricted rules instead of global open ports.

---

### `asterisk.nix`

A local SIP PBX using Asterisk PJSIP. Options namespace: `services.asteriskLocal.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable local Asterisk PBX |
| `transport.protocol` | enum (udp/tcp/tls) | `"udp"` | SIP transport |
| `transport.bind` | str | `"0.0.0.0"` | Bind address |
| `phones` | attrs of submodules | `{}` | Phone endpoint definitions |
| `phones.<name>.extension` | str | required | Dial plan extension number (must be unique) |
| `phones.<name>.password` | str or null | null | SIP password (plaintext, stored in Nix store) |
| `phones.<name>.passwordSecret` | str or null | null | sops-nix secret key for password |
| `phones.<name>.dialTimeout` | int | 20 | Ring timeout in seconds |
| `phones.<name>.maxContacts` | int | 1 | Max simultaneous registrations per AOR |
| `secrets.enable` | bool | false | Render configs via sops templates (keeps passwords out of store) |
| `secrets.owner` | str | `"asterisk"` | File owner for rendered configs |
| `secrets.group` | str | `"asterisk"` | File group |
| `secrets.mode` | str | `"0400"` | File permissions |
| `extraExtensions` | lines | `""` | Extra dialplan lines in `[from-internal]` |
| `openFirewall` | bool | false | Open 5060/udp + 10000-20000/udp |
| `liveReload` | bool | true | Reload on switch instead of restart |

Generates `pjsip.conf` and `extensions.conf` from phone attrs. Built-in extension 100 plays `hello-world` (connectivity test). Feature codes: `*1` record, `*2` blind transfer, `*3` attended transfer, `#72` park, `#74` retrieve, `*0` disconnect.

**Security note:** Use `passwordSecret` + `secrets.enable` for production. Plaintext passwords via `password` end up in `/nix/store`.

---

### `audio-stream.nix`

Options namespace: `hq.audio.*`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `streamTo` | str | `""` | Hostname/IP of remote PipeWire TCP sink |

When `streamTo != ""`: configures PipeWire client to auto-connect to remote TCP sink.

---

### `fonts.nix`

Installs font packages declared via `lucy.fonts.*` module flags (e.g. `lucy.fonts.inter = true`).

---

### `gnome.nix` / `gnome-extensions.nix`

GNOME shell configuration. `lucy.gnome.enable` flag. Extensions manager for GNOME shell extensions. Includes `gvfs` + Avahi client (`nssmdns4`) for Nautilus NFS autodiscovery via mDNS.

---

### `hm-base.nix`

Home Manager base configuration imported at the NixOS level. Sets up `home-manager.useGlobalPkgs`, `useUserPackages`, and passes `frameworkLib` and other `specialArgs` into the home-manager evaluation.

---

### `latex.nix`

Installs a TeX Live environment.

---

### `serial-getty.nix`

Enables serial console getty (for headless access via serial port).

---

### `comfyui.nix`

ComfyUI (Stable Diffusion web UI) service configuration.

---

### `waybar.nix`

NixOS-level Waybar font installation (`lucy.waybar.installFonts`).

---

## Home Manager Modules (`modules/home/`)

Auto-imported via `modules/home/default.nix` which pulls in: `niri.nix`, `opencode.nix`, `ssh.nix`, `stylix.nix`, `waybar.nix`.

---

### `home/niri.nix`

Activated by `programs.niri.enable = true`.

Generates a full `~/.config/niri/config.kdl` using frameworkLib KDL renderers and the active Stylix palette. Config includes:

- **Input:** keyboard (numlock on), touchpad (tap + natural scroll)
- **Layout:** 22px gaps, center-on-overflow, 3px border (base0E active, base03 inactive), drop shadow
- **Startup:** polkit agent, xwayland-satellite, swaybg wallpaper (if `WALLPAPER` set), waybar or eww
- **Window rules:** Firefox PiP → floating; all windows → 16px corner radius
- **Lock screen:** swaylock-effects with Stylix colors, blur, clock
- **wlogout:** lock, logout, sleep, reboot, shutdown
- **Keybindings:**
  - `Alt+Enter` → alacritty
  - `Alt+D` → fuzzel
  - `Alt+Ctrl+Escape` → lock
  - `Alt+O` → toggle overview
  - `Alt+W` → close window
  - `Alt+F` / `Alt+Shift+F` → maximize / fullscreen
  - `Alt+V` → toggle floating
  - `Alt+[1-9]` / `Alt+Ctrl+[1-9]` / `Alt+Shift+[1-9]` → workspace focus/move-column/move-window
  - Arrow keys + HJKL for navigation/movement
  - Media keys (volume, brightness, playback) work when locked

Packages installed: blueman, brightnessctl, grim, networkmanagerapplet, playerctl, slurp, swaylock-effects, wl-clipboard, wlogout.

---

### `home/waybar.nix`

Activated by `programs.waybar.enable = true`.

Top bar, 42px height, 14px top margin, 18px left/right margin. Styled with Stylix palette (gradient bar, card-style modules, rounded corners).

Modules:
| Position | Modules |
|----------|---------|
| Left | niri/workspaces, niri/window |
| Center | mpris |
| Right | custom/notifications, idle_inhibitor, clock, network, pulseaudio, battery, cpu, memory, tray, custom/power |

Notable behaviors:
- mpris: click → play/pause, middle-click → notify-send with album art, right-click → fuzzel player picker, scroll → prev/next
- custom/notifications: polls makoctl every 3s, click → dismiss all, right-click → toggle mako mode
- custom/power: click → wlogout
- cpu/memory: click → alacritty + btop

---

### `home/stylix.nix`

When `stylix.enable` is true: sets polarity dark, enables most stylix targets (waybar, GTK, bat, btop, fzf, firefox), disables alacritty/mako/rofi/zathura targets (those have custom configs). Removes legacy Kvantum symlink on activation.

---

### `home/ssh.nix`

SSH client config. Known hosts and connection options.

---

### `home/opencode.nix`

opencode AI coding tool configuration.

---

### `home/dunst.nix`

Dunst notification daemon configuration. (Used on non-niri setups; niri uses mako.)
