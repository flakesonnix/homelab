{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: {
  config = lib.mkIf config.programs.neovim.enable {
    # rust-analyzer finds stdlib sources here (no rustup in Nix).
    home.sessionVariables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    programs.neovim = {
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = true;
      withPython3 = true;
      withNodeJs = true;
      extraPackages = with pkgs; [
        tree-sitter
        ripgrep
        fd
        # Nix
        nil
        alejandra
        statix
        # Go
        go
        gopls
        gofumpt
        # Python
        pyright
        ruff
        # JS/TS + JSON/CSS
        typescript-language-server
        vscode-langservers-extracted
        eslint_d
        prettierd
        nodejs
        # Rust/C++/C#
        rust-analyzer
        rustc
        cargo
        rustfmt
        clippy
        clang-tools
        csharp-ls
        # Debug adapters (no mason; wired explicitly below)
        delve
        (python3.withPackages (ps: [ps.debugpy]))
        # PHP (phpactor: LSP + format + diagnostics in one, no Node needed)
        phpactor
        php
        phpPackages.composer
        phpPackages.php-cs-fixer
        phpstan
        phpunit
        pretty-php
        # Kotlin (JVM-based server)
        kotlin-language-server
        jre
        # Java (jdtls + neotest; no java-debug DAP in this pin)
        jdt-language-server
        # Scala (metals + scalafmt; DAP via metals worksheet only)
        metals
        scalafmt
        # Haskell (hls + fourmolu)
        haskell-language-server
        fourmolu
        # Zig (zls + zig fmt)
        zls
        zig
        # Ruby (solargraph + rubocop; rspec via neotest)
        solargraph
        rubocop
        # HTML/CSS snippets
        emmet-language-server
        # SQL (sqlfluff lint+format)
        sqlfluff
        # LaTeX (texlab LSP; latexmk/zathura from the latex system module)
        texlab
        # Typst (tinymist LSP+format, typst compiler)
        tinymist
        typst
        # JS/TS debugging (node + chrome)
        vscode-js-debug
        # C# debugging
        netcoredbg
        # Lua (Runtime + Rocks + LSP + Lint)
        lua
        luajit
        lua5_1 # Neovim-Plugins/luarocks laufen auf 5.1/LuaJIT
        luarocks
        selene
        emmylua-check
        # Lua/Sh/YAML/TOML/Markdown/Docker/Terraform
        lua-language-server
        stylua
        bash-language-server
        shfmt
        shellcheck
        yaml-language-server
        taplo
        marksman
        dockerfile-language-server
        terraform-ls
      ];
      plugins = with pkgs.vimPlugins; [
        # LSP + completion
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        cmp-nvim-lua # Lua/Neovim-API in Completion
        luasnip
        cmp_luasnip
        friendly-snippets
        lazydev-nvim # Neovim-Lua-API (vim.*) für lua_ls
        one-small-step-for-vimkind # Lua-DAP: eigene Nvim-Config debuggen
        # Finder/tree/git
        telescope-nvim
        telescope-fzf-native-nvim
        plenary-nvim
        neo-tree-nvim
        nui-nvim
        gitsigns-nvim
        # Look + help
        nvim-web-devicons
        gruvbox-nvim
        lualine-nvim
        presence-nvim
        which-key-nvim
        indent-blankline-nvim
        todo-comments-nvim
        comment-nvim
        nvim-autopairs
        trouble-nvim
        # Messages, cmdline, quickfix, search, scrollbar, sessions,
        # tasks, replace, rename, undo
        noice-nvim
        nvim-notify
        dressing-nvim
        nvim-scrollbar
        nvim-bqf
        nvim-hlslens
        # Sessions, tasks, search/replace, rename, undo, symbols
        persistence-nvim
        overseer-nvim
        grug-far-nvim
        inc-rename-nvim
        undotree
        # Debugging
        nvim-dap
        nvim-dap-ui
        nvim-dap-virtual-text
        nvim-nio
        nvim-dap-python
        nvim-dap-go
        # IDE chrome: terminal, outline, marks, tests, diff, dashboard
        toggleterm-nvim
        aerial-nvim
        harpoon2
        lspkind-nvim
        dropbar-nvim
        alpha-nvim
        diffview-nvim
        neotest
        neotest-go
        neotest-python
        neotest-rust
        neotest-jest
        neotest-phpunit
        neotest-java
        neotest-rspec
        nvim-jdtls
        nvim-metals
        vimtex
        render-markdown-nvim
        phpactor # :Phpactor* Commands (ContextMenu, Import, Transform)
        nvim-treesitter-context
        # Format + lint
        conform-nvim
        nvim-lint
        (nvim-treesitter.withPlugins (p:
          with p; [
            nix
            go
            gomod
            rust
            kotlin
            c_sharp
            cpp
            python
            javascript
            typescript
            tsx
            lua
            vim
            vimdoc
            bash
            yaml
            toml
            json
            markdown
            markdown_inline
            dockerfile
            terraform
            hcl
            regex
            query
            comment
            diff
            gitcommit
            css
            html
            java
            php
            ruby
            scala
            haskell
            zig
            sql
            latex
            bibtex
            typst
          ]))
      ];
      extraConfig = ''
        set number
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set smartindent
        set wrap
        set linebreak
        set termguicolors
        colorscheme gruvbox
      '';
      initLua = ''
        -- Leader first (mappings below rely on it).
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "
        vim.opt.signcolumn = "yes"
        vim.opt.updatetime = 250
        vim.opt.clipboard = "unnamedplus"
        vim.opt.undofile = true
        vim.opt.completeopt = { "menuone", "noselect" }
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        -- Feel: cursorline, breathing room, splits, mouse, guides.
        vim.opt.cursorline = true
        vim.opt.scrolloff = 8
        vim.opt.sidescrolloff = 8
        vim.opt.splitright = true
        vim.opt.splitbelow = true
        vim.opt.mouse = "a"
        vim.opt.confirm = true
        vim.opt.colorcolumn = "120"
        vim.opt.pumheight = 10
        vim.opt.showmode = false -- lualine shows the mode already        vim.opt.list = true
        vim.opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }
        vim.opt.timeoutlen = 300
        vim.api.nvim_create_autocmd("TextYankPost", {
          group = vim.api.nvim_create_augroup("YankHl", { clear = true }),
          callback = function() vim.highlight.on_yank({ timeout = 200 }) end,
        })
        -- Large files (>1 MiB): skip treesitter (keeps editing smooth).
        vim.api.nvim_create_autocmd("BufReadPre", {
          group = vim.api.nvim_create_augroup("LargeFile", { clear = true }),
          callback = function(args)
            local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
            if ok and stat and stat.size > 1024 * 1024 then
              vim.b[args.buf].large_file = true
              vim.opt_local.foldmethod = "manual"
              vim.opt_local.swapfile = false
            end
          end,
        })
        -- IDE defaults: unfolded treesitter folds, tabline, inlay hints on attach.
        vim.opt.foldmethod = "expr"
        vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.opt.foldenable = false
        -- netrw off (neo-tree replaces it).
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1

        -- Diagnostics look.
        vim.diagnostic.config({ virtual_text = true, severity_sort = true, update_in_insert = false })

        -- Completion.
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        require("luasnip.loaders.from_vscode").lazy_load()
        cmp.setup({
          snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
          mapping = cmp.mapping.preset.insert({
            ["<C-b>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then cmp.select_next_item()
              elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
              else fallback() end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then cmp.select_prev_item()
              elseif luasnip.jumpable(-1) then luasnip.jump(-1)
              else fallback() end
            end, { "i", "s" }),
          }),
          sources = cmp.config.sources({
            { name = "nvim_lsp" },
            { name = "nvim_lua" },
            { name = "luasnip" },
            { name = "path" },
          }, {
            { name = "buffer" },
          }),
          formatting = {
            format = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50 }),
          },
          experimental = { ghost_text = true },
        })

        -- LSP via new core API (sandbox-verified: enable() spawns the
        -- right servers; the old require("lspconfig") framework only
        -- prints a deprecation warning now). Server defaults (cmd,
        -- filetypes, roots) ship with nvim-lspconfig; here only
        -- capabilities + our own settings. Binaries come from
        -- extraPackages, no mason.
        local caps = require("cmp_nvim_lsp").default_capabilities()
        vim.api.nvim_create_autocmd("LspAttach", {
          group = vim.api.nvim_create_augroup("UserLspKeys", { clear = true }),
          callback = function(ev)
            local o = { buffer = ev.buf, silent = true }
            pcall(vim.lsp.inlay_hint.enable, true, { bufnr = ev.buf })
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, o)
            vim.keymap.set("n", "gr", vim.lsp.buf.references, o)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, o)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, o)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, o)
            vim.keymap.set("n", "<leader>rn", function()
              return ":IncRename " .. vim.fn.expand("<cword>")
            end, { buffer = ev.buf, silent = true, expr = true })
            vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, o)
            vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, o)
          end,
        })
        -- Diagnostics navigation.
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { silent = true })
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { silent = true })
        vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { silent = true })
        vim.keymap.set("n", "<leader>q", "<cmd>Trouble diagnostics toggle<cr>", { silent = true })

        -- Language servers (binaries come from extraPackages, no mason).
        local servers = {
          "gopls", "pyright", "ruff", "ts_ls", "yamlls",
          "bashls", "marksman", "taplo", "jsonls", "dockerls",
          "terraformls", "clangd", "kotlin_language_server",
          "csharp_ls", "hls", "zls", "solargraph", "emmet_ls",
          "texlab", "tinymist",
        }
        for _, name in ipairs(servers) do
          vim.lsp.config(name, { capabilities = caps })
          vim.lsp.enable(name)
        end
        -- Lua: vim.* kennen (Neovim-Config + luarocks-Projekte), kein Telemetrie.
        -- lazydev (Plugin oben) liefert vim-API + workspace-Lib, das hier
        -- ist das Fallback falls lazydev mal fehlt.
        vim.lsp.config("lua_ls", {
          capabilities = caps,
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },
              workspace = {
                checkThirdParty = false,
                library = vim.api.nvim_get_runtime_file("", true),
              },
              completion = { callSnippet = "Replace" },
              telemetry = { enable = false },
              format = { enable = false }, -- stylua via conform macht das
            },
          },
        })
        vim.lsp.enable("lua_ls")
        -- PHP: phpactor ( Hover/Goto/Complete/Refactor in einem ).
        -- composer/phpstan/php-cs-fixer kommen aus extraPackages.
        vim.lsp.config("phpactor", {
          capabilities = caps,
          init_options = {
            ["language_server_phpstan.enabled"] = false,
            ["language_server_psalm.enabled"] = false,
          },
        })
        vim.lsp.enable("phpactor")
        -- Java via nvim-jdtls (lspconfig alone misses Lombok/tests/DAP wiring).
        -- No java-debug DAP in this pin: debugging Java needs the jar manually.
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("JdtlsStart", { clear = true }),
          pattern = { "java" },
          callback = function(args)
            local root = vim.fs.root(args.buf, { "gradlew", "mvnw", ".git" })
            local project = vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p:h:t")
            require("jdtls").start_or_attach({
              cmd = {
                "jdt-language-server",
                "-data", vim.fn.stdpath("cache") .. "/jdtls/" .. project,
              },
              root_dir = root,
              capabilities = caps,
            })
          end,
        })
        -- Scala via nvim-metals (bare config: no lspconfig wrapper for it).
        local metals_config = require("metals").bare_config()
        metals_config.capabilities = caps
        metals_config.init_options.statusBarProvider = "show-message"
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("MetalsStart", { clear = true }),
          pattern = { "scala", "sbt" },
          callback = function()
            require("metals").initialize_or_attach(metals_config)
          end,
        })
        vim.lsp.config("rust_analyzer", {
          capabilities = caps,
          settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
        })
        vim.lsp.enable("rust_analyzer")
        vim.lsp.config("nil_ls", {
          capabilities = caps,
          settings = { ["nil"] = { formatting = { command = { "alejandra" } } } },
        })
        vim.lsp.enable("nil_ls")
        vim.lsp.config("gopls", {
          capabilities = caps,
          settings = { gopls = { gofumpt = true } },
        })

        -- Treesitter main-branch API: no ensure_installed (parsers come
        -- from Nix), start per buffer when a parser exists. No jsonc
        -- parser in nixpkgs: treat .jsonc as json.
        vim.filetype.add({ extension = { jsonc = "json" } })
        require("nvim-treesitter").setup()
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
          callback = function(args)
            if vim.b[args.buf].large_file then return end
            local ok, parser = pcall(vim.treesitter.get_parser, args.buf)
            if ok and parser then
              vim.treesitter.start(args.buf)
              vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end,
        })

        -- Telescope (+ fzf sorter) and pickers.
        local telescope = require("telescope")
        telescope.setup({})
        pcall(telescope.load_extension, "fzf")
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files, { silent = true })
        vim.keymap.set("n", "<leader>fg", builtin.live_grep, { silent = true })
        vim.keymap.set("n", "<leader>fb", builtin.buffers, { silent = true })
        vim.keymap.set("n", "<leader>fh", builtin.help_tags, { silent = true })

        -- Format on save (per filetype) + lint on save.
        require("conform").setup({
          formatters_by_ft = {
            nix = { "alejandra" },
            go = { "gofumpt" },
            python = { "ruff_format" },
            javascript = { "prettierd" },
            typescript = { "prettierd" },
            javascriptreact = { "prettierd" },
            typescriptreact = { "prettierd" },
            json = { "prettierd" },
            jsonc = { "prettierd" },
            yaml = { "prettierd" },
            toml = { "taplo" },
            markdown = { "prettierd" },
            lua = { "stylua" },
            sh = { "shfmt" },
            c = { "clang_format" },
            cpp = { "clang_format" },
            rust = { "rustfmt" },
            php = { "php_cs_fixer" },
            blade = { "prettierd" },
            ruby = { "rubocop" },
            haskell = { "fourmolu" },
            scala = { "scalafmt" },
            zig = { "zigfmt" },
            sql = { "sqlfluff" },
          },
          format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
        })
        require("lint").linters_by_ft = {
          python = { "ruff" },
          nix = { "statix" },
          sh = { "shellcheck" },
          javascript = { "eslint_d" },
          typescript = { "eslint_d" },
          lua = { "selene" },
          php = { "phpstan" },
          ruby = { "rubocop" },
          sql = { "sqlfluff" },
        vim.api.nvim_create_autocmd({ "BufWritePost" }, {
          callback = function() require("lint").try_lint() end,
        })

        -- Lua + PHP Feinschliff.
        -- lazydev: vim.*-API für lua_ls (eigene Nvim-Config + Plugins).
        require("lazydev").setup({ library = { "lazy.nvim" } })
        -- Blade (*.blade.php) als php+html behandeln (Treesitter php/html
        -- ist schon in withPlugins, kein extra Parser in Nix nötig).
        vim.filetype.add({
          extension = { blade = "blade" },
          pattern = { [".*%.blade%.php"] = "blade" },
        })
        -- Indents: Lua 2 Spaces (stylua-Default), PHP/Blade 4 Spaces
        -- (PSR-12), passend zu tabstop=2 global oben.
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("LuaPhpIndent", { clear = true }),
          callback = function(args)
            if args.match == "lua" then
              vim.bo[args.buf].shiftwidth = 2
              vim.bo[args.buf].tabstop = 2
            elseif args.match == "php" or args.match == "blade" or args.match == "java" then
              vim.bo[args.buf].shiftwidth = 4
              vim.bo[args.buf].tabstop = 4
            end
          end,
        })
        -- LaTeX: vimtex (latexmk baut, zathura zeigt), texlab liefert LSP.
        vim.g.vimtex_view_method = "zathura"
        vim.g.vimtex_quickfix_open_on_warning = 0
        vim.g.tex_flavor = "latex"
        -- Markdown-Vorschau inline (kein Browser nötig).
        require("render-markdown").setup({})
        -- luarocks-Hinweis: `luarocks --lua-version=5.1 init` im Projekt,
        -- dann `lua_modules/` per .luarc.json an lua_ls melden:
        -- {"workspace":{"library":["lua_modules/share/lua/5.1"]}}.
        -- Auf NixOS: Rocks mit C-Anteil brauchen gcc via `nix-shell -p lua51Packages.luarocks gcc`.

        -- Small UI helpers (all defaults, just enabled).
        require("neo-tree").setup({ close_if_last_window = true })
        require("gitsigns").setup({ current_line_blame = true })
        -- Cyberdeck-Look (wie Desktop): Lualine-Theme direkt aus der
        -- Stylix-Palette statt gruvbox — Statusline + Tabs passen zu GNOME.
        local deck = {
          bg     = "${config.lib.stylix.colors.withHashtag.base00}",
          bg_alt = "${config.lib.stylix.colors.withHashtag.base01}",
          sel    = "${config.lib.stylix.colors.withHashtag.base02}",
          muted  = "${config.lib.stylix.colors.withHashtag.base03}",
          fg     = "${config.lib.stylix.colors.withHashtag.base05}",
          red    = "${config.lib.stylix.colors.withHashtag.base08}",
          yellow = "${config.lib.stylix.colors.withHashtag.base0A}",
          green  = "${config.lib.stylix.colors.withHashtag.base0B}",
          cyan   = "${config.lib.stylix.colors.withHashtag.base0C}",
          pink   = "${config.lib.stylix.colors.withHashtag.base0D}",
          purple = "${config.lib.stylix.colors.withHashtag.base0E}",
        };
        local function deck_mode(accent)
          return {
            a = { bg = accent, fg = deck.bg, gui = "bold" },
            b = { bg = deck.sel, fg = deck.fg },
            c = { bg = deck.bg_alt, fg = deck.fg },
          };
        end
        local cyberdeck_lualine = {
          normal   = deck_mode(deck.pink),
          insert   = deck_mode(deck.green),
          visual   = deck_mode(deck.purple),
          replace  = deck_mode(deck.red),
          command  = deck_mode(deck.cyan),
          inactive = {
            a = { bg = deck.bg_alt, fg = deck.muted, gui = "bold" },
            b = { bg = deck.bg_alt, fg = deck.muted },
            c = { bg = deck.bg_alt, fg = deck.muted },
          },
        };
        require("lualine").setup({
          options = {
            theme = cyberdeck_lualine,
            -- One line for all splits (no stacked per-window bars).
            globalstatus = true,
            -- Slant separators = smooth mode/color transitions.
            section_separators = { left = "", right = "" },
            component_separators = { left = "", right = "" },
            -- Plugin sidebars keep a flat, quiet line.
            disabled_filetypes = {
              statusline = {
                "alpha", "neo-tree", "aerial", "undotree", "diffview",
                "toggleterm", "OverseerList", "grug-far", "Trouble",
                "dapui_scopes", "dapui_breakpoints", "dapui_stacks",
                "dapui_watches", "neotest-summary",
              },
            },
            refresh = { statusline = 250, tabline = 500 },
          },
          sections = {
            lualine_a = {
              -- Single-letter mode + icon (no "NORMAL" brick).
              { "mode", fmt = function(s) return s:sub(1, 1) end, icon = "" },
            },
            lualine_b = { "branch", "diff", "diagnostics" },
            lualine_c = {
              {
                "filename",
                path = 1, -- relative path, keeps long names readable
                symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" },
              },
            },
            lualine_x = {
              -- Only show when off-default (no utf-8/unix noise).
              { "encoding", cond = function() return vim.bo.fileencoding ~= "" and vim.bo.fileencoding ~= "utf-8" end },
              { "fileformat", cond = function() return vim.bo.fileformat ~= "unix" end },
              "filetype",
            },
            lualine_y = { "progress" },
            lualine_z = { "location" },
          },
          tabline = {
            lualine_a = {
              {
                "buffers",
                use_mode_colors = true,
                symbols = { modified = " ●", alternate_file = "", directory = "" },
              },
            },
            -- Tabs only when more than one exists.
            lualine_z = {
              { "tabs", use_mode_colors = true, cond = function() return #vim.api.nvim_list_tabpages() > 1 end },
            },
          },
        })
        -- Discord Rich Presence: immer aktiv solange Neovim läuft
        -- (kein Idle-Status — zeigt Datei + Zeile + Projekt, mit Timer).
        require("presence").setup({
          auto_update        = true,
          main_image         = "neovim",
          neovim_image_text  = "Cyberdeck Nvim",
          enable_line_number = true,
          show_time          = true,
          buttons            = true,
        })
        require("ibl").setup()
        require("Comment").setup()
        require("nvim-autopairs").setup({})
        require("todo-comments").setup()
        require("trouble").setup()
        require("which-key").setup()

        -- Smooth motion (mini.nvim ships with the setup, no new plugin).
        local animate = require("mini.animate")
        animate.setup({
          cursor = { enable = true },
          scroll = { enable = true, timing = animate.gen_timing.linear({ duration = 80, unit = "total" }) },
          resize = { enable = true },
          open = { enable = false },
          close = { enable = false },
        })

        -- Messages, cmdline, popups (Noice needs nui + notify, both in).
        require("notify").setup({ timeout = 3000 })
        require("dressing").setup()
        require("noice").setup({
          lsp = {
            override = {
              ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
              ["vim.lsp.util.stylize_markdown"] = true,
            },
            progress = { enabled = true },
          },
          presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
          },
        })

        -- Sessions (auto-save/restore), tasks, project search/replace,
        -- inline rename, undo tree, code/symbol navigation.
        require("scrollbar").setup()
        require("scrollbar.handlers.gitsigns").setup()
        require("bqf").setup()
        require("hlslens").setup()
        local hl_opts = { noremap = true, silent = true }
        vim.keymap.set("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        vim.keymap.set("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        vim.keymap.set("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        vim.keymap.set("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        require("persistence").setup()
        vim.keymap.set("n", "<leader>qs", function() require("persistence").load() end, { silent = true })
        vim.keymap.set("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { silent = true })
        vim.keymap.set("n", "<leader>qd", function() require("persistence").stop() end, { silent = true })
        require("overseer").setup()
        vim.keymap.set("n", "<leader>ot", "<cmd>OverseerToggle<cr>", { silent = true })
        vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { silent = true })
        require("grug-far").setup({})
        vim.keymap.set("n", "<leader>sr", "<cmd>GrugFar<cr>", { silent = true })
        require("inc_rename").setup()
        vim.keymap.set("n", "<leader>u", "<cmd>UndotreeToggle<cr>", { silent = true })
        vim.keymap.set("n", "<leader>ds", builtin.lsp_document_symbols, { silent = true })
        vim.keymap.set("n", "<leader>ws", builtin.lsp_workspace_symbols, { silent = true })
        vim.keymap.set("n", "<leader>ci", builtin.lsp_incoming_calls, { silent = true })
        vim.keymap.set("n", "<leader>co", builtin.lsp_outgoing_calls, { silent = true })
        local hl_opts = { noremap = true, silent = true }
        vim.keymap.set("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        vim.keymap.set("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        vim.keymap.set("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], hl_opts)
        vim.keymap.set("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], hl_opts)

        -- Debugging (adapters from Nix store paths, no mason).
        local dap = require("dap")
        local dapui = require("dapui")
        require("nvim-dap-virtual-text").setup()
        dapui.setup()
        dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
        dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
        dap.listeners.before.event_exited["dapui"] = function() dapui.close() end
        require("dap-python").setup("${pkgs.python3.withPackages (ps: [ps.debugpy])}/bin/python")
        require("dap-go").setup()
        -- JS/TS debugging (node + chrome). No codelldb/lldb-dap in this
        -- pin, so no native Rust/C++ DAP (delve/debugpy/js/netcoredbg wired).
        dap.adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "''${port}",
          executable = {
            command = "${pkgs.vscode-js-debug}/bin/js-debug",
            args = { "''${port}" },
          },
        }
        dap.configurations.javascript = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch node (current file)",
            program = "''${file}",
            cwd = "''${workspaceFolder}",
          },
          {
            type = "pwa-chrome",
            request = "attach",
            name = "Attach chrome (:9222)",
            port = 9222,
            webRoot = "''${workspaceFolder}",
          },
        }
        for _, ft in ipairs({ "typescript", "typescriptreact", "javascriptreact" }) do
          dap.configurations[ft] = dap.configurations.javascript
        end
        -- C# debugging (netcoredbg, console apps).
        dap.adapters.netcoredbg = {
          type = "executable",
          command = "${pkgs.netcoredbg}/bin/netcoredbg",
          args = { "--interpreter=vscode" },
        }
        dap.configurations.cs = {
          {
            type = "netcoredbg",
            request = "launch",
            name = "Launch .NET (dll path?)",
            program = function()
              return vim.fn.input("dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
            end,
            cwd = "''${workspaceFolder}",
          },
        }
        -- Lua: eigene Nvim-Config live debuggen via :lua require"osv".launch().
        -- PHP/Xdebug: Adapter nicht in Nixpkgs (kein php-debug-adapter),
        -- Template zum Selbst-Verdrahten falls du vscode-php-debug manuell holst:
        -- dap.adapters.php = { type = "executable",
        --   command = vim.fn.expand("~/.vscode-php-debug/out/phpDebug.js") };
        -- dap.configurations.php = { { type = "php", request = "launch",
        --   name = "Listen for Xdebug", port = 9003 } };
        -- Dazu in php.ini: xdebug.mode=debug, xdebug.client_port=9003.
        vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { silent = true })
        vim.keymap.set("n", "<leader>dc", dap.continue, { silent = true })
        vim.keymap.set("n", "<leader>do", dap.step_over, { silent = true })
        vim.keymap.set("n", "<leader>di", dap.step_into, { silent = true })
        vim.keymap.set("n", "<leader>du", dapui.toggle, { silent = true })
        vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { silent = true })

        -- Terminal panel, outline, file marks, tests, diff, dashboard.
        require("toggleterm").setup({ open_mapping = [[<c-\>]], direction = "float" })
        require("aerial").setup()
        vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle<cr>", { silent = true })
        local harpoon = require("harpoon")
        harpoon:setup()
        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { silent = true })
        vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { silent = true })
        require("neotest").setup({
          adapters = {
            require("neotest-go"),
            require("neotest-python"),
            require("neotest-rust"),
            require("neotest-jest"),
            require("neotest-phpunit"),
            require("neotest-java"),
            require("neotest-rspec"),
          },
        })
        vim.keymap.set("n", "<leader>tt", function() require("neotest").run.run() end, { silent = true })
        vim.keymap.set("n", "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, { silent = true })
        vim.keymap.set("n", "<leader>ts", function() require("neotest").summary.toggle() end, { silent = true })
        vim.keymap.set("n", "<leader>to", function() require("neotest").output.open({ enter = true }) end, { silent = true })
        vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { silent = true })
        require("treesitter-context").setup()
        require("dropbar").setup()
        require("alpha").setup(require("alpha.themes.startify").config)
      '';
    };
  };
}
