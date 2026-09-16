---
aliases: [Home modules, HM modules]
tags: [module, nixos]
type: module
namespace: programs.*
---

# Home modules

[[20-Modules/Modules-MOC|← Modules]] · Auto-imported via `modules/home/default.nix`: `niri`, `opencode`, `ssh`, `stylix`, `waybar` (+`dunst` via `home/lucy/default.nix`). Editor (`home/lucy/editor.nix`, full IDE) + terminal/fonts via `home/lucy/programs/*` + `data/bundles/*.nix` — see [[20-Modules/Editor|Editor (Neovim IDE)]].

## editor — Neovim full IDE (`programs.neovim.enable`, `home/lucy/editor.nix`)

No mason — binaries via `extraPackages`, servers via `vim.lsp.config` + `vim.lsp.enable`, parsers via Nix treesitter.
- LSP: `nil_ls` (alejandra) + `gopls` (gofumpt) + `pyright`/`ruff` + `ts_ls` + `rust_analyzer` (clippy) + `clangd` + `csharp_ls` + `phpactor` + `kotlin_language_server` + `lua_ls`/`yamlls`/`bashls`/`marksman`/`taplo`/`jsonls`/`dockerls`/`terraformls`. `RUST_SRC_PATH` set, `inlay_hint` on attach, `gd/gD/gr/gi/K/<leader>ca/rn/D/f`, `[d`/`]d`.
- Complete/find/format/lint: `nvim-cmp` + `luasnip` + `lspkind` (ghost text) · `telescope` + fzf (`<leader>ff/fg/fb/fh`) + `neo-tree` (`<leader>e`) · `conform` format-on-save (alejandra/gofumpt/ruff/prettierd/stylua/shfmt/clang_format/rustfmt) + `nvim-lint` on save (ruff/statix/shellcheck/eslint_d).
- DAP/tests/terminal/symbols: `nvim-dap` + ui + virtual-text (`<leader>db/dc/do/di/du/dr`), `dap-python` (debugpy) + `dap-go` · `neotest` + go/python/rust/jest (`<leader>tt/tf/ts/to`) · `toggleterm` (`<C-\>` float) · `overseer` (`<leader>ot/or`) · `aerial` (`<leader>o`) + `dropbar` + `treesitter-context` + `harpoon2` (`<leader>a`, `<C-e>`).
- UX/chrome: `gruvbox` + cyberdeck `lualine` (Stylix base00–0E) + `presence-nvim` (Discord) · `noice` + `notify` + `dressing` · `mini.animate` (cursor/scroll/resize) · `scrollbar` + gitsigns handler + `bqf` + `hlslens` · `persistence` sessions (`<leader>qs/ql/qd`) + `grug-far` (`<leader>sr`) + `inc-rename` (`<leader>rn`) + `undotree` (`<leader>u`) + `trouble` (`<leader>q`) + `diffview` (`<leader>gd`) + `alpha/startify` · `which-key`/`ibl`/`todo-comments`/`Comment`/`autopairs` · 2-space, `cursorline`, `colorcolumn=120`, large-file (>1 MiB) treesitter off.
- Langs: Nix/Go/Rust/Python/JS-TS/Kotlin/C#/C++/Lua/Sh/YAML/TOML/Markdown/Docker/Terraform + PHP.

Fonts: `GeistMono Nerd Font Mono` everywhere — `data/packages/home.nix:geist-mono` (`pkgs.nerd-fonts.geist-mono`, tag `desktop/fonts`, via `desktop` bundle `packageToggles`) → alacritty (`home/lucy/programs/alacritty/default.nix`, 13pt Regular/Bold) + GNOME mono (`gnome-theme.nix`, `GeistMono Nerd Font Mono 11`) + Inter 11 UI. Replaces `JetBrainsMono`.

## niri (`programs.niri.enable`)

Generates `~/.config/niri/config.kdl` (KDL renderers + Stylix palette):
- Input: numlock on, tap + natural scroll · Layout: 22px gaps, center-on-overflow, 3px border (base0E active/base03 inactive), drop shadow
- Startup: polkit agent, xwayland-satellite, swaybg wallpaper (if `WALLPAPER` set), waybar or eww
- Rules: Firefox PiP → floating, 16px corner radius everywhere · swaylock-effects + wlogout
- Keys: `Alt+Enter/D/O/W/F/V`, `Alt+[1-9]` (+Ctrl/Shift variants), HJKL+arrows, media keys work when locked
- Packages: blueman, brightnessctl, grim, nm-applet, playerctl, slurp, swaylock-effects, wl-clipboard, wlogout

## waybar (`programs.waybar.enable`)

Top bar, 42px height, 14px top margin, 18px side margins. Stylix gradient + card-style modules.
Left `niri/workspaces+window` · center `mpris` · right `notifications/idle/clock/network/pulse/battery/cpu/memory/tray/power`.
Clicks: mpris play/pause + notify art + fuzzel picker, notifications poll makoctl every 3s, power→wlogout, cpu/mem→btop.

## stylix

`stylix.enable` → dark polarity, most targets on (waybar/GTK/bat/btop/fzf/firefox), alacritty/mako/rofi/zathura off (custom configs). Removes legacy Kvantum symlink.

## ssh / opencode / dunst

- `ssh`: client config, known hosts.
- `opencode`: AI coding tool config (`modules/home/opencode.nix`).
- `dunst`: notification daemon, auto-disabled while `programs.niri.enable` (niri setups use mako).
