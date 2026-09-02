# Data Model

All declarative host and home configuration lives in `data/`. The in-repo framework (`lib/framework`, exposed as `frameworkLib`) reads this data and resolves it into NixOS/Home Manager config at evaluation time.

## Directory structure

```
data/
├── roles/                  # Shared role definitions
│   ├── core.nix
│   ├── desktop.nix
│   ├── dev.nix
│   ├── gaming.nix
│   └── llm.nix
├── bundles/                # Home Manager bundle definitions
│   ├── core.nix
│   ├── desktop.nix
│   └── dev.nix
├── presets/                # Host preset (module flag sets)
│   ├── gaming-base.nix
│   ├── gaming-performance.nix
│   └── gaming-steam.nix
├── packages/
│   ├── system.nix          # Tagged system/user package registry
│   └── home.nix            # Tagged home package registry
├── hosts/
│   ├── x270/
│   │   ├── settings.nix    # NixOS config merged into host
│   │   ├── roles.nix       # [ "desktop" "dev" "llm" "gaming" ]
│   │   ├── module-flags.nix
│   │   ├── packages.nix
│   │   ├── power.nix
│   │   └── services.nix
│   └── mireo/
│       └── settings.nix
└── home/lucy/
    ├── bundles.nix         # Extra bundles beyond role-derived ones
    ├── roles.nix           # [ "core" "desktop" "dev" ]
    └── settings.nix        # Home manager settings
```

---

## Roles

Roles are the top-level unit of intent. A host or home declares a list of role names; the framework loads each role definition and resolves dependencies.

### Role file shape

```nix
{
  meta = {
    description = "Human-readable description";
    targets = [ "host" "home" ];   # which sides this role applies to
    requires = {
      host = [ "other-role" ];     # roles that must also be present
      home = [ "core" ];
    };
    conflicts = {
      host = [];
      home = [];
    };
  };

  host = {
    moduleFlags = {
      lucy.gaming.enable = true;   # NixOS option → value
    };
    packageTags = [ "desktop" "dev" ];  # pull tagged packages from system registry
    presets = [ "gaming-base" ];        # apply preset files
  };

  home = {
    bundles = [ "core" "desktop" ];  # activate home bundles
  };
}
```

### Available roles

| Role | Targets | Effect |
|------|---------|--------|
| `core` | home | Activates `core` bundle |
| `desktop` | host + home | Enables niri, fonts, waybar fonts; activates `desktop` bundle |
| `dev` | host + home | Adds dev/network/monitoring package tags; activates `dev` bundle |
| `gaming` | host | Applies `gaming-base`, `gaming-performance`, `gaming-steam` presets |
| `llm` | host | Adds `llm` package tag |

### Host role data

```
data/hosts/x270/roles.nix   →  [ "desktop" "dev" "gaming" ]

data/home/lucy/roles.nix    →  [ "core" "desktop" "dev" ]
```

---

## Bundles

Bundles are Home Manager configuration slices activated by roles.

### Bundle file shape

```nix
{
  meta = {
    description = "...";
    targets = [ "home" ];
  };

  programs = {
    bash.enable = true;
    neovim.enable = true;
    # ... any home-manager programs.* toggle
  };

  settings.stylix = {
    enable = true;
    targets.alacritty.enable = false;
  };

  packageToggles = [ "comma" "manix" ];  # names from home package registry

  services.flatpak = {
    enable = true;
    packages = [ "com.teamspeak.TeamSpeak" ];
  };

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "26.05";
    pointerCursor = { ... };
  };

  xdg.desktopEntries.lmstudio = { ... };
}
```

### Available bundles

| Bundle | Programs enabled |
|--------|-----------------|
| `core` | bash, git, neovim, htop, btop, bat, fzf, ssh, opencode, nh; packages: comma, manix, nix-output-monitor |
| `desktop` | alacritty, dunst, eww, firefox, fuzzel, gnomeTheme, niri, rofi, starship, thunderbird, vesktop, zathura; stylix; flatpak: TeamSpeak; packages: jetbrains-mono, nautilus |
| `dev` | packages: android-studio |

---

## Presets

Presets are named sets of module flag values applied at the host level. They are referenced by roles via `host.presets`.

### Preset file shape

```nix
{
  meta = {
    description = "...";
    targets = [ "host" ];
  };

  moduleFlags = {
    lucy.gaming.enable = true;
    lucy.gaming.performance.cpuFreqGovernor = "performance";
  };
}
```

### Available presets

| Preset | Module flags set |
|--------|-----------------|
| `gaming-base` | `lucy.gaming.enable = true` |
| `gaming-performance` | performance governor, disable power profiles daemon, capSysNice, sysctl lowLatency |
| `gaming-steam` | Steam, GameMode, Gamescope, MangoHud |

---

## Package registries

### `data/packages/system.nix`

Keyed by name. Each entry:

```nix
{
  description = "CLion IDE";
  targets = [ "user" ];        # "user", "system", or "font"
  packages.user = [ pkgs.jetbrains.clion ];
  tags = [ "dev" "jetbrains" ];
}
```

Entries in this file: `firefox`, `discord`, `lmstudio`, `clion`, `ollama`, `swaybg`, `devBase` (gcc/gdb/cmake/ninja/...), `pwvucontrol`, `scrcpy`, `nload`, `iotop`, `iftop`.

Roles reference tags (`packageTags = ["desktop" "dev"]`); the framework collects all packages whose tags intersect the host's active tag set.

### `data/packages/home.nix`

Same shape, but for home packages:

```nix
{
  comma = {
    description = "comma (run programs without installing)";
    targets = [ "home" ];
    packages.home = [ pkgs.comma ];
    tags = [ "cli" "nix" ];
  };
}
```

Entries: `jetbrains-mono`, `nautilus`, `comma`, `manix`, `nix-output-monitor`, `android-studio`.

Referenced by bundle `packageToggles` lists.

---

## Per-host data

Files in `data/hosts/<host>/` are loaded by the framework's `loadHostDirectory`. Common files:

| File | Purpose |
|------|---------|
| `settings.nix` | NixOS config merged directly (hostname, boot, network, etc.) |
| `roles.nix` | List of role names |
| `module-flags.nix` | Extra module flag overrides beyond what roles provide |
| `packages.nix` | Extra package selections |
| `services.nix` | Service configuration |
| `power.nix` | Power management settings |

---

## Homectl Manifest (M1)

`homectl/manifest.nix` is the **build-time source of truth** for the control plane. It is pure Nix (like `lib/topology.nix`): `flake.nix` → `homectlArtifacts = import ./homectl/manifest.nix { lib, pkgs, configurations = self.nixosConfigurations, deployNodes = self.deploy.nodes }` → `packages.homectl-manifest = writeText manifest.json` + `packages.homectl-ui = writeText ui.json` → committed to `homectl/artifacts/` and served by `homectl-api` (`GET /api/v1/meta` forwards them verbatim as `any`; Go never invents hosts/VMs).

`manifest.json` (`version: 1`):
- `hosts: { <name>: { hostname, roles, bundles, presets, moduleFlags, packageTags, packages: {tag->[pkg]} } }` — `roles` from `data/hosts/<host>/roles.nix` (see below), `bundles/presets/packageTags` derived via `roles → host/home` payloads, `moduleFlags` merged.
- `vms: { <vm>: { host: "mireo", ip, mem, vcpu, autostart, tcpPorts, udpPorts, volumes: [{mountPoint,size}] } }` — extracted from `microvm.vms` (`systemd.network.networks."20-lan".address`, `microvm.{mem,vcpu,volumes}`, firewall ports).
- `deployNodes: { <host>: {hostname, sshUser} }`, `proxy`, `plugins` (`lucy.homectl.agent.plugins` when `enable`), `catalog` (roles/bundles/presets metadata + package registries).

`ui.json`:
- `navigation` — default `Dashboard, Hosts, Journal, Terminal, Deploy, (VMs if hasVms), NixOS, Git, GitHub, Monitoring, Network, Settings` + `ui.navigation` from `lucy.homectl.ui` when `apiHost` set.
- `dashboard.widgets` — one `host-summary` per host + `dashboardWidgets`, `featureFlags` (`terminal`, `files`, `containers`, `tailscale`, `proxy`), `rbac` (default `admin * *`).

M1 fixes:
- `hasVms` was `vmCatalog.hostsVms` (always missing, `false`) → now `attrNames vmCatalog` — `hasVms` now correctly true when mireo has 7 VMs, so `/vms` navigation appears.
- `hostRoles` check was `dir.value ? roles.nix` (invalid Nix — `roles.nix` is not a valid identifier, so always false) → now `hasAttr "roles.nix" dir.value` — `x270` now correctly shows `roles [desktop dev gaming]`, `bundles [desktop dev]`, `presets [gaming-*]`.
- `mireo` intentionally has no `roles.nix` (server profile, `roles: []`, `bundles: []`, `presets: []`), not a bug — declarative config comes from `settings.nix` directly; roles remain Nix-originated for `x270`/`home`.

---

## Per-user data

Files in `data/home/lucy/` are loaded by `loadHomeDirectory`:

| File | Purpose |
|------|---------|
| `roles.nix` | List of home roles |
| `bundles.nix` | Extra bundles beyond role-derived ones |
| `settings.nix` | Direct home-manager config overrides |
