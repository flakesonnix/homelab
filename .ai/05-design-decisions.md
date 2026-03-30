# Design Decisions - Complete Record

## Decision 1: Nixpkgs Version - nixos-unstable (Fixed)

### Context
Initially used nixpkgs 24.11 due to nixos-unstable having a bug with mkRenamedOptionModule.

### Decision
Switched back to nixos-unstable after the bug was fixed.

### Current Status
Using nixos-unstable successfully.

---

## Decision 2: Niri Configuration - Using Lassulus Wrappers

### Context
User requested using nixpkgs programs.niri module. Initially tried nixpkgs but user wanted wrappers from Lassulus.

### Decision
Use `wrappers.wrapperModules.niri.apply` from Lassulus/wrappers for declarative niri configuration.

### Implementation
```nix
# In flake.nix:
wrappers = {
  url = "github:lassulus/wrappers";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In hosts/p50/default.nix:
let
  niri-wrapped = wrappers.wrapperModules.niri.apply {
    inherit pkgs;
    settings = {
      input = { ... };
      binds = { ... };
      spawn-at-startup = [ "waybar" ];
      layout = { gaps = 16; };
    };
  };
in {
  environment.systemPackages = [ niri-wrapped.wrapper ];
  services.displayManager.sessionPackages = [ niri-wrapped.wrapper ];
}
```

### Benefits
- Declarative Nix configuration instead of KDL
- Generates and validates KDL config automatically
- Sets NIRI_CONFIG environment variable
- Type-safe module system

---

## Decision 3: Profile-based Configuration

### Context
Profiles were defined but not used in the original configuration.

### Decision
Import profiles/desktop.nix into flake.nix modules for better organization.

### Implementation
```nix
modules = [
  ./nix-settings.nix
  ./profiles/desktop.nix
  ./hosts/p50
  ...
]
```

### Profiles
- `profiles/base.nix`: Common system config (i18n, unfree, firefox, printing, rtkit, gnupg agent)
- `profiles/desktop.nix`: Desktop config (GDM, GNOME, X server, PipeWire)

---

## Decision 4: Home Manager Module Stubs - Enabled

### Context
modules/home had stub modules with enable options that were always false.

### Decision
Enable all module stubs (shell, git, editor) and import them in home/lucy/default.nix.

### Implementation
```nix
lucy.shell.enable = true;
lucy.git.enable = true;
lucy.editor.enable = true;
```

---

## Decision 5: Stylix Configuration

### Context
Stylix was configured inline in home/lucy/default.nix.

### Decision
Move stylix configuration to a proper module in modules/home/stylix.nix with:
- Custom base16 color scheme
- Waybar target enabled
- GTK theming

### Implementation
Custom dark color scheme matching original hardcoded values in home/lucy/default.nix.

---

## Decision 6: EasyEffects with Presets

### Context
User requested EasyEffects with JackHack96 presets.

### Decision
Created home-manager module that:
- Installs easyeffects package
- Fetches presets from JackHack96/EasyEffects-Presets GitHub repo
- Symlinks preset JSON files to ~/.config/easyeffects/output/

### Implementation
```nix
lucy.easyeffects.enable = true;
```

---

## Decision 7: Package Additions

### Packages Added
- vlc, p7zip, tor-browser: User requested
- teamspeak3, teamspeak6-client: User requested
- easyeffects: User requested with presets
- noisetorch: Noise suppression for microphone

---

## Future Design Decisions Needed

1. **MicroVM Integration**: For running VMs (requires nixos-hardware first)
2. **nixos-hardware Integration**: Proper GPU/PRIME config for ThinkPad P50
3. **SOPS Integration**: Secrets management with age encryption
4. **flake-parts Migration**: Could improve flake organization
