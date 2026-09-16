---
aliases: [Editor, Neovim, Nvim IDE]
tags: [module, home]
type: module
namespace: programs.neovim
---

# Editor — Neovim full IDE

[[20-Modules/Modules-MOC|← Modules]] · [[20-Modules/Home-Modules|Home modules]] · Source: `home/lucy/editor.nix` (550 lines, gated on `programs.neovim.enable`, imported via `home/lucy/default.nix:20`). `core` bundle → `nvim` on PATH (`defaultEditor`, `vi`/`vim` aliases, `withRuby/Python3/NodeJs`).

No mason — LSP binaries via `extraPackages`, servers via `vim.lsp.config` + `vim.lsp.enable`, treesitter parsers via Nix (`nvim-treesitter.withPlugins`, start-per-buffer, `jsonc→json`).

## LSP (`vim.lsp.config/enable`)

Toolchain: `nil`/`alejandra`/`statix` · `go`/`gopls`/`gofumpt` · `pyright`/`ruff` · `typescript-language-server`/`eslint_d`/`prettierd`/`vscode-langservers-extracted` · `rust-analyzer`/`rustc`/`cargo`/`rustfmt`/`clippy` (`RUST_SRC_PATH` set) · `clang-tools` · `csharp-ls` · `phpactor` · `kotlin-language-server` + `jre` · `lua-language-server`/`stylua` · `bash-language-server`/`shfmt`/`shellcheck` · `yaml-language-server`/`taplo`/`marksman`/`dockerfile-language-server`/`terraform-ls` · `tree-sitter`/`ripgrep`/`fd`/`nodejs`.

Enabled: `gopls` `pyright` `ruff` `ts_ls` `lua_ls` `yamlls` `bashls` `marksman` `taplo` `jsonls` `dockerls` `terraformls` `clangd` `kotlin_language_server` `csharp_ls` `phpactor` + `rust_analyzer` (clippy check) + `nil_ls` (alejandra format) + `gopls` (gofumpt). `cmp_nvim_lsp` caps, `inlay_hint` on `LspAttach`.

Keys: `gd/gD/gr/gi` goto · `K` hover · `<leader>ca` action · `<leader>rn` IncRename · `<leader>D` typedef · `<leader>f` format · `[d`/`]d` diag nav · `<leader>ds/ws` symbols · `<leader>ci/co` calls.

## Complete / find / format / lint

- Complete: `nvim-cmp` + `cmp-nvim-lsp/buffer/path` + `luasnip` + `friendly-snippets` + `lspkind`, ghost text, `<C-b/f/Space/e/CR/Tab/S-Tab>`.
- Find/tree/git: `telescope` + `telescope-fzf-native` (`<leader>ff/fg/fb/fh`, `ds/ws/ci/co`) · `neo-tree` (`<leader>e`, netrw off) · `gitsigns` (blame) · `nui/plenary/devicons`.
- Format (`conform`, on save): nix→alejandra, go→gofumpt, python→ruff_format, js/ts/json/yaml/md→prettierd, toml→taplo, lua→stylua, sh→shfmt, c/cpp→clang_format, rust→rustfmt.
- Lint (`nvim-lint`, `BufWritePost`): python→ruff, nix→statix, sh→shellcheck, js/ts→eslint_d.
- Search/replace/rename/undo: `grug-far` (`<leader>sr`) · `inc-rename-nvim` · `undotree` (`<leader>u`) · `nvim-hlslens` + `nvim-bqf`.

## DAP / test / terminal / outline

- DAP: `nvim-dap` + `dap-ui` + `virtual-text` + `nvim-nio`, `dap-python` (debugpy store path) + `dap-go`. Keys `<leader>db/dc/do/di/du/dr`. Rust/C++ adapter (codelldb) → follow-up, Python+Go wired.
- Tests: `neotest` + `neotest-go/python/rust/jest` (`<leader>tt/tf/ts/to`).
- Tasks/terminal: `overseer` (`<leader>ot/or`) · `toggleterm` (`<C-\>` float).
- Outline/marks/diff/start: `aerial` (`<leader>o`) + `dropbar` + `treesitter-context` · `harpoon2` (`<leader>a`, `<C-e>`) · `diffview` (`<leader>gd`) · `alpha/startify` · `trouble` (`<leader>q`).

## Look / feel

`gruvbox` + cyberdeck `lualine` from Stylix palette (`config.lib.stylix.colors`, mode colors pink/green/purple/red/cyan) + buffer tabline · `presence-nvim` Discord RPC (file+line+timer) · `noice` + `notify` (3s) + `dressing` · `mini.animate` (cursor/scroll 80ms/resize, open/close off) · `scrollbar` + gitsigns handler · `which-key` + `ibl` + `todo-comments` + `Comment` + `autopairs`.

Defaults: `number`, 2-space `expandtab`, `cursorline`, `scrolloff=8`, `colorcolumn=120`, `pumheight=10`, `listchars`, `timeoutlen=300`, yank-hl, `undofile`, `clipboard=unnamedplus`, `foldmethod=expr` (treesitter, start unfolded), large-file (>1 MiB) → no treesitter/swapfile.

## History

- Full IDE setup (LSP/completion/finder/format/lint) → `vim.lsp.config/enable` migration + Go toolchain → DAP/terminal/outline/tests/UI round → UX round (Noice/notify/scrollbar/defaults) → font swap JetBrainsMono→GeistMono → smooth round (mini.animate/ghost text/large-file guard) → IDE round 3 (sessions/tasks/replace/symbols) → Rust fix + PHP (`phpactor`) → cyberdeck lualine + presence.
