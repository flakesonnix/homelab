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
        # Kotlin (JVM-based server)
        phpactor
        kotlin-language-server
        jre
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
        luasnip
        cmp_luasnip
        friendly-snippets
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
        vim.opt.list = true
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
          "gopls", "pyright", "ruff", "ts_ls", "lua_ls", "yamlls",
          "bashls", "marksman", "taplo", "jsonls", "dockerls",
          "terraformls", "clangd", "kotlin_language_server",
          "csharp_ls", "phpactor",
        }
        for _, name in ipairs(servers) do
          vim.lsp.config(name, { capabilities = caps })
          vim.lsp.enable(name)
        end
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
          },
          format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
        })
        require("lint").linters_by_ft = {
          python = { "ruff" },
          nix = { "statix" },
          sh = { "shellcheck" },
          javascript = { "eslint_d" },
          typescript = { "eslint_d" },
        }
        vim.api.nvim_create_autocmd({ "BufWritePost" }, {
          callback = function() require("lint").try_lint() end,
        })

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
          options = { theme = cyberdeck_lualine },
          tabline = { lualine_a = { "buffers" } },
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
        -- Rust/C++/C debugging (codelldb/lldb-dap) needs its adapter
        -- store path verified first — follow-up, Python+Go are wired.
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
