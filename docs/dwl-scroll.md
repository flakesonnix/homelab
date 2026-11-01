# dwl-scroll

An opt-in scrolling layout for upstream dwl, not a replacement compositor.
Compatibility baseline: dwl **0.9**, wlroots **0.20.2**, nixpkgs
`02c087f3fe673c9e317f206a627cb6b910336dbe` (the root input's `nixpkgs_2`
lock node, not EWM's separate nixpkgs). The source and dependency hashes
come from the existing `flake.lock`; no additional flake input or overlay.

## Architecture (implementation contract)

Before implementing the layout, these are the chosen ownership rules:

- `Monitor.columns` owns a persistent ordered list of `Column` allocations.
  Each column owns a separate list of clients and its own width fraction.
- `Client.column` and `Client.column_link` provide explicit membership.
  Neither dwl's tiling list nor its MRU focus list determines column order.
- Mapping/monitor assignment attaches clients; unmapping/monitor changes
  detach them and immediately free empty columns. A monitor transfer creates
  a new column at the destination. Output removal uses dwl's existing
  `closemon`/`setmon` path, including recovery after all outputs disappear.
- Floating and fullscreen clients retain their column slots, but are excluded
  from column sizing/navigation. Initially floating clients acquire a slot
  only when first tiled. This restores ordering when toggling either mode.
- Tags stay dwl tags: visibility filters persistent column membership rather
  than constructing new columns. Single tags have independent viewport offsets;
  combined tag views share a separate offset. Mixed-tag columns are allowed.
- A monitor stores its last arranged focus, tag mask and usable geometry.
  Focus changes reveal the destination; ordinary relayout does not undo manual
  panning. Resizing/removal clamps the viewport to the remaining content.
- The scrolling layout positions clients outside the usable area without
  dwl's usual position clamp. Surface clips and border intersections prevent
  those clients from spilling onto another output. Other layouts keep the
  original resize/clamping behavior. Leaving scrolling or toggling floating
  restores ordinary surface and border clips; fullscreen restores its slot
  and explicitly reveals the client on exit.
- Focus enters through dwl's existing `focusclient`; the scrolling hook runs
  after keyboard activation. Internal pointer refreshes carry time zero and
  therefore do not trigger sloppy focus. No animation/event-loop framework.

The patch series separates the layout/lifecycle foundation from management
actions and optional wheel input. Tests exercise the same layout C source
with a minimal scene adapter; they are not a substitute for compositor testing.

## Package and session

```sh
nix build .#dwl-scroll
./result/bin/dwl-scroll       # from a suitable TTY or nested Wayland session
nix build .#checks.x86_64-linux.dwl-scroll-module
nix build .#checks.x86_64-linux.dwl-scroll-headless
nix build .#checks.x86_64-linux.dwl-scroll-settings
```

The new files are staged (`git add` only; nothing committed) because Nix
flakes cannot evaluate untracked files. Your uncommitted work and this
repository's index of prior changes stay otherwise untouched.

The common NixOS module aggregator imports the module; p53 enables the
session in `data/hosts/p53/module-flags.nix`:

```nix
lucy.dwlScroll.enable = true;
```

Rebuild using the repository's normal command, then select **dwl-scroll** in
GDM. This does not change the default session, replace `pkgs.dwl`, enable
`programs.dwl`, or remove GNOME/SwayFX/EWM. mireo stays headless.
For another NixOS configuration, import `nixosModules.dwl-scroll` from this flake.

The session wrapper imports the Wayland environment **after** dwl creates its
socket (using dwl's `-s` command), starts `dwl-scroll-session.target`, and stops
that target on exit. Its PolicyKit agent is scoped to this target. Portal
selection is per-desktop (`gtk`, with `wlr` for screenshots/screencasts).
The startup script then runs [dwlb](https://github.com/kolunmi/dwlb), consuming
dwl's status pipe to display tags, layout and focused title on each output.
There is no animation daemon, idle-lock service, or compositor IPC daemon.
`Super+Ctrl+Escape` locks manually; configure idle locking separately if needed.

On p53, the session startup hook runs `swaybg` in **fill** mode with
`/home/lucy/Pictures/wallpaper.webp`. It exits when dwl closes its Wayland
connection, leaving other desktop sessions unchanged. The image is read at
runtime and is not copied into Git or the Nix store. Its configuration lives
in `data/hosts/p53/settings.nix`.

### dwlb status bar

The NixOS session uses the pinned `pkgs.dwlb` package in `-no-ipc` mode with
Iosevka **10pt**, with Symbols Nerd Font Mono for icons. It occupies the top of each monitor; tiled windows use the
remaining space. It is started via dwl's `-s` hook, not as a separate service:
that hook supplies the stdin stream required for live tags/layout/title.
The bar exits with the compositor. A transparent **Waybar companion** overlays
the same top row, with just tray icons and the clock at the right edge. It
does not create a second bottom bar or reserve another row of tiled space.
No Niri modules are started; other desktop sessions are unchanged. dwlb's
status updater leaves room for the companion, growing with registered tray icons.
The companion uses a private Waybar build with layer-shell zone **-1** for
non-reserving surfaces. This anchors it to the output's top edge instead of
placing it below dwlb's reserved area. The normal Waybar package is unchanged.

The bar uses dwl's `settings.colors` directly: `root` for the dark background,
`focus` for text and the selected tag, `border` for occupied tags, and `urgent`
for urgent tags. Selected/urgent tags use dark text for contrast. The title
keeps the dark background, with 4px vertical padding and Iosevka 10pt. Changing
the dwl palette updates the bar automatically on the next rebuild/session.

The right-hand status updates every two seconds with battery/charging icons,
CPU load and temperature, RAM usage in
GB (no percentage), and GPU temperature. A small clock shows **HH:MM**; the
date is displayed **only when hovering over the clock**. All metrics have
Nerd Font icons. Network state and controls appear **once**, through the
nm-applet icon beside the clock; the metrics updater does not read or display
SSID/connection names. CPU/RAM/power/temperature data comes from
`/proc` and `/sys`. ThinkPad GPU sensor labels are supported; the NVIDIA fallback
only calls `nvidia-smi` for already-active GPUs, otherwise showing `GPU off`.
Unavailable sensors are displayed as `n/a` rather than failing the bar.

`nm-applet --indicator` provides the tray icon and connection menu when
NetworkManager is enabled. The services `dwl-scroll-status`, `dwl-scroll-tray`
and `dwl-scroll-nm-applet` start/stop with `dwl-scroll-session.target` and are
restricted to the dwl Wayland session. The companion uses the same palette and
Iosevka font as dwl/dwlb; its symbols use the installed Nerd Font fallback.

The package is also installed for commands such as:

```sh
dwlb -toggle-visibility all
systemctl --user restart dwl-scroll-status.service
```

For manual status text, first stop `dwl-scroll-status.service`; otherwise the
metrics updater replaces it on the next tick. Inline status commands are
disabled, so status values are data rather than clickable shell commands.

Tag/layout mouse clicks require the optional dwl IPC patch and are not enabled
here. Use the configured Super shortcuts for tag/layout changes. Custom status
text can be updated through dwlb's command socket independently of compositor
IPC. After rebuilding, restart the dwl session; if GDM retains an older session
path, reboot or restart GDM after saving your work.

Optional session-local configuration, for example:

```nix
{pkgs, ...}: {
  lucy.dwlScroll = {
    enable = true;
    # Only set this if needed on the particular hybrid-GPU host:
    extraSessionCommands = ''
      export WLR_DRM_DEVICES="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card)"
    '';
    startupCommands = ''
      ${pkgs.swaybg}/bin/swaybg -c '#181825' &
    '';
    package = pkgs.callPackage ../../pkgs/dwl-scroll {
      # Supply a complete header, with command paths adjusted as desired.
      configH = ./my-dwl-config.h;
      enableXWayland = false;
    };
  };
}
```

The `callPackage` and header paths in that example are relative to a file in
`hosts/p53/`. For Home Manager integration, existing terminal/launcher/GTK
settings can be reused. Scope additional HM user services to
`dwl-scroll-session.target`, not Niri's or Sway's session target. **Do not write
`~/.config/dwl/config.h`**: dwl's C configuration is compiled into its package.
No separate Home Manager module or runtime-generated layout configuration is
needed. The standalone package's desktop file starts dwl directly; use the
NixOS module for the environment/target/portal wrapper.

## Configuration and keys

### p53: Niri shortcuts with Super

`data/hosts/p53/settings.nix` imports `pkgs/dwl-scroll/niri-keybinds.nix` into
`lucy.dwlScroll.settings`. It copies the supported shortcuts from
`modules/home/niri.nix`, replacing **Alt with Super**. Niri itself is unchanged.
This overrides the standalone package's older bindings listed below.

| Binding | Action |
|---|---|
| Super+Return / D | Alacritty / built-in application launcher |
| Super+Ctrl+Escape | Lock with swaylock |
| Super+Shift+A | Audio controls (pwvucontrol) |
| Super+arrows or H/J/K/L | Focus column / window |
| Super+Ctrl+arrows or H/J/K/L | Move column / window |
| Super+Shift+arrows or H/J/K/L | Focus monitor |
| Super+Ctrl+Shift+arrows or H/J/K/L | Move **focused window** to monitor |
| Super+W | Close focused window |
| Super+V | Toggle floating |
| Super+F | Maximize column to the usable width / restore its previous width |
| Super+Shift+F | Toggle fullscreen |
| Super+R | Next preset column width |
| Super+minus / equal | Change column width by −10 / +10 percentage points |
| Super+period | Expel window into a new right-hand column |
| Super+1…9 | View numbered dwl tag |
| Super+Ctrl+1…9 or Super+Shift+1…9 | Move **focused window** to tag |
| Super+horizontal wheel | Focus column |
| Super+Ctrl+horizontal wheel | Move column |
| Super+Shift+vertical wheel | Focus column |
| Super+Ctrl+Shift+vertical wheel | Move column |
| Print or Super+Shift+S | Select screenshot area (grim + slurp) |
| Ctrl+Print or Super+Ctrl+Shift+S | Screenshot all outputs |
| Super+Shift+P | Toggle display power (press again to restore) |
| Super+Shift+E or Super+Ctrl+Delete | Exit compositor |
| Audio/media/brightness keys | Same wpctl, playerctl and brightnessctl commands as Niri |

Screenshots are saved to `~/Pictures/Screenshots/`. Command bindings use
absolute Nix store paths. dwl does not run these media bindings while locked;
Niri's `allow-when-locked` flag has no equivalent here.

Not every Niri action has a dwl equivalent. Monitor/tag transfers move
one window, not an entire column. Tags are static, not dynamic workspaces.
Overview/hotkey overlay, relative workspace navigation/reordering, first/last
column actions, consume-or-expel/consume-into-column, reverse presets,
per-window heights, window maximization/centering, floating-focus switching,
window-only screenshots and shortcut-inhibitor toggling remain unbound.
Super+F toggles column maximization without entering fullscreen or unstacking
its windows. The previous width is saved per column; changing width or selecting
a preset ends maximization. The Niri fullscreen key remains **Super+Shift+F**.
Super+vertical wheel alone is unbound, not continuous panning.

dwl-only operations remain available without colliding with copied shortcuts:

| Binding | Action |
|---|---|
| Super+Alt+H / L | Pan viewport |
| Super+Alt+I | Toggle new-right/current-column insertion |
| Super+Alt+Return / Super+Alt+Shift+Return | Merge into right / left column |
| Super+Alt+[ / ] | Transfer window into adjacent column |
| Super+Alt+S / T / V / M | Scrolling / tile / floating / monocle layout |
| Super+Tab / 0 | Previous tag view / all tags |

Settings are typed Nix options; partial overrides retain other defaults:

```nix
lucy.dwlScroll.settings = {
  colors.fullscreenBg = "000000";
  scroll.width = 0.6;
  extraKeybinds = [
    { mods = ["logo"]; key = "b"; action = "spawn"; arg.v = ["firefox"]; }
  ];
};
```

Use `lib.mkForce` on `keybinds` to replace p53's preset rather than append to
it. `logo` is dwl's name for Super. Rebuild to apply changes; there is no runtime
keybinding reload.

### Built-in application launcher

**Super+D** opens dwl-scroll's own dmenu-style search panel on the focused
output. It is rendered directly in the compositor's Wayland scene, above
applications and bars but below the session lock: no fuzzel, X11 window or
separate launcher service is started. The panel uses dwl's root/focus/urgent
palette and Iosevka 10pt, with up to eight visible results.

Each result has a **20px application icon** from its desktop entry. The launcher
uses `gtk-icon-theme-name` from `~/.config/gtk-3.0/settings.ini` (Papirus-Dark by
default), searches XDG icon directories with theme inheritance/hicolor fallback,
and supports named PNG/SVG/XPM icons and absolute file icons. Packaged Papirus
icons provide a fallback outside a fully configured desktop session; missing or
unreadable icons ultimately get a small application-window glyph. Raster images
keep their aspect ratio/alpha, HiDPI outputs get appropriately sized images,
and symbolic icons follow the selected row's foreground color. Icons are cached
until the menu closes. Lookup/decoding uses libsfdo, GdkPixbuf and librsvg, without
initializing GTK or connecting a separate UI to the display.

Type to search installed `.desktop` applications by name, keywords, executable
or desktop ID. Search is case-insensitive, supports Unicode and multiple words,
and ranks exact/prefix names first. XDG directory precedence and desktop-entry
visibility (`Hidden`, `NoDisplay`, `OnlyShowIn`, `TryExec`) follow GIO.

| Key | Action |
|---|---|
| Up / Down, Shift+Tab / Tab | Previous / next result |
| Ctrl+P / Ctrl+N | Previous / next result |
| Home / End, PageUp / PageDown | First / last result, previous / next page |
| Backspace / Ctrl+Backspace | Remove character / word |
| Ctrl+U or Ctrl+L / Ctrl+W | Clear query / remove word |
| Enter | Launch selected application; no-op with no matches |
| Escape or Super+D | Dismiss and restore keyboard focus |
| Mouse wheel / left click | Select result / launch clicked result |
| Right click or click outside | Dismiss |

Launcher input is not forwarded to applications or the input method. Output
removal/disable and session locking dismiss the panel; it cannot open while
locked. Desktop-entry activation uses GIO in a fresh helper invocation of the
same binary (`dwl-scroll -a desktop-id`), keeping activation/D-Bus work outside
the compositor event loop. This preserves standard `Exec` field-code and
terminal-entry handling, without evaluating the search query through a shell.
It is an application launcher, not a shell-command prompt or IME text editor.

Existing `commands.launcher` / `menucmd` configuration remains available for
custom bindings using `action = "spawn"; arg.v = "menucmd";`; its default is
still fuzzel. The new built-in binding uses `action = "showlauncher";` instead.
Custom raw headers remain valid; `LAUNCHER_FONT` can optionally override the
Pango font via `extraConfig` or the raw header. Rebuild and start a new dwl
session to load the built-in launcher; the running compositor is not replaced.

### Built-in Discord Rich Presence

The compositor can publish Rich Presence directly to the desktop Discord
client's local Unix socket. No RPC daemon, external helper, network client or
Discord token is needed. It is disabled by default; p53 explicitly enables it
with the supplied public application ID and focused-app sharing:

```nix
lucy.dwlScroll.settings.discordRpc = {
  enable = true;
  clientId = "123456789012345678"; # replace with your public application ID
  showApp = true; # explicit opt-in to sharing the focused app's name/ID
};
```

Presence contains the upstream dwl logo (with a `dwl-scroll` hover label),
`Wayland compositor: dwl-scroll`, elapsed session time, and optionally the
focused application's desktop-entry name or app ID. Discord fetches the logo
from dwl's public Codeberg avatar; the compositor still only uses local IPC.
**Window titles, documents, search queries and account tokens are never read.** Set
`showApp = false` to keep app information private, or `enable = false` to stop
the integration. Raw headers may define `DISCORD_RPC_ENABLED`,
`DISCORD_RPC_CLIENT_ID` and `DISCORD_RPC_SHOW_APP`; absent macros stay disabled.

Locking immediately clears presence and disconnects; no IPC connection is made
while locked. Unlocking reconnects automatically. Shutdown clears presence too.
Updates are deduplicated and limited to once per 15 seconds; reconnect attempts
are spaced five seconds apart. An absent/stopped Discord client, malformed
frames, a full socket or a rejected ID cannot block or terminate the compositor.
Frame sizes, queues and work per callback are bounded. Socket lookup is confined
to the current user's private `XDG_RUNTIME_DIR`, including normal desktop,
Flatpak and Snap Discord paths, rather than shared `/tmp` sockets.

Discord must be running locally and its Activity Privacy settings must allow
activity sharing. The application name and application-list icon are controlled
by the Discord Developer Portal application, separately from the presence logo.
Rebuild and start a new dwl session to activate this compiled feature.
No live account activity is published during the tests:
they use private mock IPC servers, including the real headless compositor's
focus/lock/unlock/exit lifecycle and native ASan/UBSan protocol tests.

### Standalone/default package bindings

`pkgs/dwl-scroll/config.h` is the full default header. The package substitutes
absolute paths for alacritty, fuzzel and swaylock. A custom `configH` is passed
unchanged, so replace those command strings yourself rather than keeping the
`@terminal@`, `@launcher@` and `@locker@` template placeholders.

Defaults: 55% column width; 12px column gaps; 8px row gaps; 12px outer padding;
160px keyboard pan; new columns to the right; minimal focus reveal; click/key
focus. Set `sloppyfocus = 1` for focus-follows-pointer, `scroll_center = 1` for
centering on focus changes, and `scroll_insert = -1/0/1` for left/current/right.
Widths scale with the usable output width, not with the number of columns.
Client minimum widths can enlarge their column. Row heights divide the usable
height equally (remainder pixels go to the earliest rows). Very small outputs
or oversized client minimum-size hints can prevent every row fitting at once.

`MODKEY` defaults to **Super**. Niri/Sway still use Alt; p53's dwl preset above
intentionally uses Super instead. dwl
0.9 uses modifier-independent key symbols: write lowercase `XKB_KEY_h` even
when binding Shift+H. Navigation stops at edges rather than wrapping.

| Binding | Action |
|---|---|
| Super+H / L | Focus adjacent column (its MRU visible window) |
| Super+K / J | Focus previous/next window inside column |
| Super+Shift+H / L | Move entire column left/right |
| Super+Shift+K / J | Move window up/down inside column |
| Super+Ctrl+H / L | Pan viewport without changing keyboard focus |
| Super+Ctrl+Shift+H / L | Move window into adjacent column |
| Super+Return | Launch alacritty |
| Super+Ctrl+Return | Merge visible rows into right column |
| Super+Ctrl+Shift+Return | Merge visible rows into left column |
| Super+I | Toggle new-right/current-column insertion |
| Super+Ctrl+[ / ] | Select new-left/new-right insertion |
| Super+[ / ] | Decrease/increase column width by 5 percentage points |
| Super+R | Cycle widths: 33%, 50%, 67%, 100% |
| Super+Shift+Return | Split focused window into a new right column |
| Super+D | Open built-in application launcher |
| Super+Q | Close focused window |
| Super+Shift+Space | Toggle floating |
| Super+F | Toggle fullscreen |
| Super+Ctrl+Escape | Lock using swaylock |
| Super+Shift+E | Exit compositor (not a live reload) |
| Super+S / T / V / M | Scrolling / upstream tile / floating / monocle layout |
| Super+Ctrl+J / K | Stock focus-stack navigation, also for non-scrolling layouts |
| Super+Ctrl+= / - | Stock master-window count adjustment |
| Super+Ctrl+, / . | Stock master-factor adjustment |
| Super+Ctrl+Z | Stock zoom/master action |
| Super+1…9 | View tag |
| Super+Shift+1…9 | Assign window to tag |
| Super+Ctrl+1…9 | Toggle tag visibility |
| Super+Ctrl+Shift+1…9 | Toggle window tag membership |
| Super+Tab / 0 | Previous tag view / all tags |
| Super+, / . | Focus left/right output |
| Super+Shift+, / . | Send window to left/right output |
| Super+left / right mouse drag | Float and move / resize |
| Super+middle mouse | Toggle floating |

Scrolling actions are inert in other layouts and while a floating/fullscreen
client is selected. A split of a singleton is a no-op. Merging moves only
visible tiled rows; hidden-tag/floating/fullscreen slots stay in their original
column. Moving a column moves all its slots, including hidden ones.

`scroll_wheel_mod = MODKEY` enables continuous axis-delta panning with Super
held (both vertical wheels and horizontal touchpad axes). Set it to zero to
disable. `scroll_wheel_scale` controls sensitivity; ordinary unmodified events
continue through upstream dwl. There is no inertia or animation. Generic
`Axis` bindings remain available in the header. Touchpad gestures/swipes,
overview, animations and momentum scrolling are intentionally not implemented.

## Maintenance

The original djpohly/dwl project moved to `codeberg.org/dwl/dwl`; the package
uses that upstream, exactly as nixpkgs does. Baseline source: `v0.9`, NAR hash
`sha256-PYBOi/A9n1611XBEaZW9PolSfjwe1KWoI2VbVrS2s0Q=`. Source code, dependencies,
license, Xwayland option and build machinery are inherited from `pkgs.dwl`.
The package name, binary, desktop entry and manual are separate from vanilla
dwl. It reports `dwl 0.9-scroll1`. No global overlay or extra flake input.

Apply in order:

1. `0001-scrolling-layout.patch`: explicit ownership, lifecycle hooks, clipped
   layout, viewport, basic navigation. Adds `scroll.c`, included by `dwl.c` in
   dwl's single-translation-unit style; Makefile dependencies/dist are updated.
2. `0002-management-and-wheel.patch`: list-based movement/split/merge, insertion
   controls, width adjustment/presets, column maximize/restore, continuous
   modifier+axis panning.
3. `0003-builtin-launcher.patch`: compositor-owned scene/input lifecycle hooks
   and activation-helper entry point. The package supplies `launcher.c` and
   `launcher-model.c`, linked with Pango/Cairo and GIO. `launcher-icons.c` adds
   freedesktop icon lookup and native CPU image rendering.
4. `0004-discord-rpc.patch`: event-loop and lock/cleanup hooks for the opt-in
   local Rich Presence client in `discord-rpc.c` (JSON-GLib).

The package deliberately rejects dwl versions other than 0.9. On a nixpkgs
update, inspect the **root** lock input (not the first nixpkgs node), compare
upstream Client/Monitor, `resize`, `focusclient`, `setmon`, `setfloating`,
`setfullscreen`, mapping/unmapping and axis/key paths. Rebase all four patches
onto a clean new upstream source; never ship rejects or fuzzy applications.
Update the header for upstream API/key-symbol changes, the version guard,
reported patch revision and this compatibility note. Run the checks below
and build vanilla dwl again. Keep source/build trees and screenshots outside
Git. No vendored compositor fork, generated protocol headers or binaries.

## Verification

The package's `checkPhase` compiles the **patched** `scroll.c` with a small
scene adapter, runs deterministic behavioral tests plus 3,000 randomized
operations, then repeats under AddressSanitizer/UndefinedBehaviorSanitizer
with leak detection. The module check verifies opt-in behavior, preservation
of p53's existing sessions/default, an unchanged mireo, and coexistence with
unmodified `programs.dwl`. Checks are included in `full-ci-checks`.

The same build also runs the real GIO-backed launcher-model tests natively and
under ASan/UBSan: visibility rules, case-insensitive multiword search, ranking,
Unicode normalization/editing, empty results and bounded query input. The runtime
suite checks the actual launcher pixels, cancellation and focus restoration,
input isolation, `.desktop` activation, Unicode search, repeat suppression,
output resize/disable, and lock/unlock using a private test Wayland locker.

The headless check runs the **real built compositor** with the pixman renderer,
two headless outputs and real foot clients. It drives the default keyboard
bindings with wtype, changes outputs with wlr-randr and inspects grim screenshots
for positions, stable width, stacking and cross-output clipping, including
floating an entirely clipped client and switching away from the scrolling
layout. Dependencies
such as Python/Pillow and these test clients are not compositor dependencies.

`dwl-scroll-settings` also builds the Nix-rendered defaults and p53's Niri-style
preset, then repeats the runtime suite with each. The preset runs with a real
dwlb reading dwl's status pipe and tests bar show/hide and exclusive space
reservation, including pixel checks against the dwl palette. Fixture tests
cover battery/charging icons, CPU deltas, GB memory accounting, no network-name
polling, CPU/ThinkPad GPU sensors, missing data, tray spacing and suspended-GPU
safety. Module tests verify clock/date tooltip configuration. The runtime suite
starts the companion on a private D-Bus and checks its background pixels are
on the same first row as dwlb, not below the exclusive zone.
The preset test drives Super
navigation (both arrows and H/J/K/L), Ctrl movement, floating/fullscreen,
column maximize/restore (including stacked windows), numbered tags, monitor
transfers and Super+W, and checks that Alt+W does not
close the window. Evaluation assertions reject duplicate shortcut combinations
and verify the fullscreen background declaration and Super modifier mask.

Compilation alone is never considered a runtime test. The headless suite does
not exercise physical DRM outputs, real pointer/touchpad devices, GPU drivers,
or a display-manager login. Xwayland support is compiled, but the test clients
are native Wayland applications.

### Verification record (2026-10-31)

- **Passed:** clean zero-fuzz application of both patches; default package
  build and the no-Xwayland variant; compiler logs contain no C warnings.
- **Passed:** standalone core-only patch build and both patches using the
  patched upstream `config.def.h`, without the repository's custom header.
- **Passed:** unmodified root-nixpkgs `dwl` 0.9 built locally with substitution
  disabled; custom configuration path substitution compiled successfully.
- **Passed:** layout tests, 3,000 deterministic randomized operations, ASan,
  UBSan and leak checks in each variant's build.
- **Passed:** opt-in module check, including a full enabled-p53 toplevel
  evaluation and vanilla/custom session coexistence; existing SwayFX, EWM and
  desktop-regression checks; disabled p53 toplevel evaluation.
- **Passed:** real-repo flake evaluation after staging, with p53's
  `lucy.dwlScroll.enable` set: the p53 toplevel evaluates from the repo
  itself and its GDM session list contains `dwl-scroll-session` alongside
  ewm-system, gnome and swayfx, with `services.displayManager.defaultSession`
  unchanged (still unset — GDM keeps the last chosen session).
- **Passed:** real headless runtime tests for map/close, stable-width columns,
  vertical insertion/focus/movement, column movement, transfer/split/merge,
  manual pan without focus changes, cross-output clipping, width controls,
  tags, floating/fullscreen transitions, stock-layout transitions, sending a
window to another monitor, resizing/disabling that output, and restart.

Flake checks were built from a pure temporary snapshot of tracked files plus
the new sources, preserving existing work and leaving the Git index untouched.
Full repository CI/OS builds and deployment were not performed. Existing
Avahi deprecation warnings from the host configuration remain unrelated.

**Not tested:** physical monitor disconnect/reconnect, DRM/GPU acceleration,
real mouse/touchpad axis input or sloppy-focus interaction, GDM login and
systemd user-session teardown, portal/screen-sharing operation, real locking,
Xwayland applications, IMEs, and application-specific popup/subsurface behavior.

**Not implemented:** animation/momentum frameworks, multi-finger gestures or
overview. Continuous modifier+axis panning is immediate, not an animation.
Tags have independent offsets but remain dwl's tag model, not Niri's dynamic
workspaces. There is no persistence of columns across compositor restarts;
clients reconnecting after a restart receive new columns.

### Nix settings and Super keymap follow-up

Verified builds: `dwl-scroll-module`, `dwl-scroll-settings`,
`dwl-scroll-headless`, `dwl-scroll-no-xwayland`, and p53's configured
`lucy.dwlScroll.package`. The settings check runs both default and Niri-preset
headless tests. Module tests also check partial settings/default merging and
reject unknown options, non-float widths and non-boolean modifiers. p53's
`system.build.toplevel.drvPath` evaluates successfully. No full OS build,
activation, physical key/media tests or GDM login was performed in this
follow-up; existing Avahi deprecation warnings remain.

### Built-in launcher follow-up

Verified `dwl-scroll`, `dwl-scroll-no-xwayland`, `dwl-scroll-headless`,
`dwl-scroll-settings` and `dwl-scroll-module`. Native and ASan/UBSan model tests
include discovering an application installed after the first search. The real
headless suites exercise launch/cancel, Unicode search, keyboard isolation and
focus restoration, held-shortcut repeat suppression, output changes, and a
private lock/unlock client with launcher attempts while locked. Both the static
header and Nix-rendered default/p53 keymaps are covered; bar/tray tests still
pass. Physical pointer input, IMEs and a real display-manager login were not
tested. The running user compositor was not replaced; rebuild and log in again
to load the launcher. The retained external `menucmd` and unused standalone
`scrollmaximize` function can produce harmless compiler warnings.

The broader `nix flake check --no-build` evaluates all dwl checks, but stops at
the unrelated `pxe-desktop-boot` package: `hosts/pxe-desktop` still defines the
removed `services.journald.extraConfig` option (now `services.journald.settings.Journal`).
