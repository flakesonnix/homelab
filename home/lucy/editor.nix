{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: {
  config = lib.mkIf config.programs.neovim.enable {
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
        clang-tools
        csharp-ls
        # Debug adapters (no mason; wired explicitly below)
        delve
        (python3.withPackages (ps: [ps.debugpy]))
        # Kotlin (JVM-based server)
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
        which-key-nvim
        indent-blankline-nvim
        todo-comments-nvim
        comment-nvim
        nvim-autopairs
        trouble-nvim
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
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, o)
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
          "terraformls", "rust_analyzer", "clangd", "kotlin_language_server",
          "csharp_ls",
        }
        for _, name in ipairs(servers) do
          vim.lsp.config(name, { capabilities = caps })
          vim.lsp.enable(name)
        end
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
        require("gitsigns").setup()
        require("lualine").setup({
          options = { theme = "auto" },
          tabline = { lualine_a = { "buffers" } },
        })
        require("ibl").setup()
        require("Comment").setup()
        require("nvim-autopairs").setup({})
        require("todo-comments").setup()
        require("trouble").setup()
        require("which-key").setup()

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
