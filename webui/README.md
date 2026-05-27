# WebUI

Pure Nix-based web interface for managing dotfiles configuration.

## Structure

```
webui/
├── lib/
│   ├── layout.nix      # Base HTML layout (head/sidebar/footer)
│   └── pages/
│       ├── dashboard.nix
│       ├── roles-host.nix
│       ├── roles-home.nix
│       ├── presets.nix
│       └── bundles.nix
├── static/
│   └── style.css       # Catppuccin-styled CSS
└── server              # Bash HTTP socket handler
```

## How It Works

1. **Pages** are defined in Nix as strings containing HTML
2. **Layout** provides shared head, sidebar, and footer
3. Each page imports layout and wraps content
4. **Build** copies Nix-generated HTML to output directory
5. **Server** serves static files via socat socket

## Adding a New Page

1. Create `webui/lib/pages/<name>.nix`:

```nix
{
  lib,
  ...
}: let
  inherit (import ../layout.nix {}) head footer;
in ''
  ${head}
  <h2>Page Title</h2>
  <p>Content here</p>
  ${footer}
''
```

2. Add route in `server`:

```bash
/path)
    cat "$WEBUI_ROOT/lib/pages/<name>.nix"
    ;;
```

3. Add navigation link in `layout.nix`

## Running

```bash
nix run .#webui
```

Then open http://localhost:8080

## Checks

- `webui-html-validate` - validates all pages import layout.nix

Run: `nix flake check`