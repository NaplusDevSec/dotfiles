-- =====================================================================
-- Neovim Configuration for Low-Level C/Assembly Development (42 School friendly)
-- =====================================================================

-- =====================================================================
-- 0. MACHINE-LOCAL SETTINGS (Unversioned / Machine-specific)
-- =====================================================================
-- Loads '~/.config/nvim/local.lua' if available. Expected return format:
--   return { school42 = true, login = "jdoe", mail = "jdoe@student.42.fr" }
-- * school42 = true  -> Enables Norminette-compliant real tabs and 42 header
-- * school42 = false -> Uses spaces and skips 42 header generation
local function load_local_config()
    local chunk = loadfile(vim.fn.stdpath("config") .. "/local.lua")
    if chunk then
        local ok, result = pcall(chunk)
        if ok and type(result) == "table" then
            return result
        end
    end
    return {}
end

local local_cfg = load_local_config()
local school42 = local_cfg.school42 == true

-- =====================================================================
-- 1. LEADER KEYS CONFIGURATION
-- =====================================================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- =====================================================================
-- 2. CORE EDITOR SETTINGS & 42 NORMINETTE RULES
-- =====================================================================
vim.opt.number = true             -- Show absolute line numbers
vim.opt.relativenumber = true     -- Show relative line numbers for efficient jumping
vim.opt.cursorline = true         -- Highlight the current line
vim.opt.mouse = "a"               -- Enable full mouse support

-- Indentation: 42 Norminette requires real tabs (width 4); standard projects use spaces
vim.opt.tabstop = 4               -- Number of spaces a Tab counts for
vim.opt.shiftwidth = 4            -- Size of an indent
vim.opt.expandtab = not school42  -- Real tabs for 42 students, spaces otherwise

-- Whitespace visualization symbols
vim.opt.list = true
vim.opt.listchars = {
    tab = '▸-',
    space = '·',
    trail = '˽',
}

-- Custom Filetype Detection (x86 Assembly / MASM support)
vim.filetype.add({
    extension = {
        asm = "asm",
        inc = "asm",
    },
})

-- =====================================================================
-- 3. NATIVE LUA 42 HEADER GENERATOR
-- =====================================================================
local function insert_42_header()
    local WIDTH = 80
    local filename = vim.fn.expand("%:t")
    local user = local_cfg.login or os.getenv("USER") or "user"
    local mail = local_cfg.mail or (user .. "@student.42.fr")
    local current_date = os.date("%Y/%m/%d %H:%M:%S")

    local function line(left, right)
        left = "/*    " .. left
        right = right .. " */"
        local pad = WIDTH - #left - #right
        if pad < 1 then pad = 1 end
        return left .. string.rep(" ", pad) .. right
    end

    local border = "/* " .. string.rep("*", WIDTH - 6) .. " */"

    -- Scan existing buffer to preserve original 'Created:' date and creator
    local total_lines = vim.api.nvim_buf_line_count(0)
    local scan = vim.api.nvim_buf_get_lines(0, 0, math.min(15, total_lines), false)
    local created_date = current_date
    local created_user = user

    local borders = {}
    for i, l in ipairs(scan) do
        if l:match("^/%* %*+ %*/$") then
            table.insert(borders, i)
        end
        local c_date, c_user = l:match("^/%*%s+Created:%s+(%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d)%s+by%s+(%S+)")
        if c_date and c_user then
            created_date = c_date
            created_user = c_user
        end
    end

    local header = {
        border,
        line("", ""),
        line("", ":::      ::::::::  "),
        line(filename, ":+:      :+:    :+:  "),
        line("", "+:+ +:+         +:+    "),
        line("By: " .. user .. " <" .. mail .. ">", "+#+  +:+       +#+        "),
        line("", "+#+#+#+#+#+   +#+            "),
        line("Created: " .. created_date .. " by " .. created_user, "#+#    #+#              "),
        line("Updated: " .. current_date .. " by " .. user, "###   ########.fr      "),
        line("", ""),
        border,
        "",
    }

    -- Remove existing header before inserting the updated one
    if #borders >= 2 and borders[1] == 1 then
        local last = borders[2]
        if scan[last + 1] == "" then last = last + 1 end
        vim.api.nvim_buf_set_lines(0, 0, last, false, {})
    end

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

-- Register keymap and user command for 42 Header (<Ctrl+Alt+h> or :Stdheader)
if school42 then
    vim.keymap.set({ "n", "i" }, "<C-M-h>", insert_42_header, { desc = "Insert or update 42 Header" })
    vim.api.nvim_create_user_command("Stdheader", insert_42_header, {})
end

-- =====================================================================
-- 4. GLOBAL KEYBINDINGS
-- =====================================================================
-- Toggle file explorer sidebar using backtick (`)
vim.keymap.set("n", "`", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle NvimTree" })

-- Jump to symbol definition via Ctrl + Left Click
vim.keymap.set("n", "<C-LeftMouse>", vim.lsp.buf.definition, { desc = "Go to LSP Definition" })

-- Toggle Markdown Live Preview via Leader + m
vim.keymap.set("n", "<leader>m", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })

-- Telescope Fuzzy Finder Mappings
local function telescope(picker)
    return function() require("telescope.builtin")[picker]() end
end
vim.keymap.set("n", "<leader>ff", telescope("find_files"), { desc = "Find files by name" })
vim.keymap.set("n", "<leader>fg", telescope("live_grep"), { desc = "Search text across project (Grep)" })
vim.keymap.set("n", "<leader>fb", telescope("buffers"), { desc = "List open buffers" })
vim.keymap.set("n", "<leader>fh", telescope("help_tags"), { desc = "Search Neovim help tags" })

-- =====================================================================
-- 5. PLUGIN MANAGER SETUP (lazy.nvim)
-- =====================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- 1. Syntax Highlighting Engine (nvim-treesitter: main branch)
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSUpdate",
        config = function()
            -- On main branch, nvim-treesitter.configs is removed.
            -- Highlighting is handled natively by Neovim's built-in vim.treesitter.
            vim.api.nvim_create_autocmd("FileType", {
                callback = function()
                    pcall(vim.treesitter.start)
                end,
            })
        end,
    },

	-- 2. File Explorer Sidebar
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = false,
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                sync_root_with_cwd = true,
                respect_buf_cwd = true,
                update_focused_file = { enable = true, update_root = true },
                view = { width = 30 },
            })
        end,
    },

    -- 3. Fuzzy Finder (Telescope)
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("telescope").setup({
                defaults = {
                    file_ignore_patterns = { "%.o", "%.a", "a.out", "%.dSYM/", "%.git/" },
                },
            })
        end,
    },

    -- 4. Language Server Protocol (C/C++ via clangd)
    {
        "neovim/nvim-lspconfig",
        config = function()
            vim.lsp.config["clangd"] = {
                -- Add custom server options here if needed (e.g., cmd, filetypes)
            }
            vim.lsp.enable("clangd")
        end,
    },

    -- 5. Markdown Buffer Enhancements (Render-Markdown)
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        opts = {},
        ft = { "markdown" },
    },

    -- 6. Markdown Live Browser Preview
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = "cd app && npm install && git checkout -- .",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
    },

    -- 7. Colorscheme: Tokyo Night
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            -- Available styles: tokyonight-night, tokyonight-storm, tokyonight-moon, tokyonight-day
            vim.cmd([[colorscheme tokyonight-night]])
        end,
    },

    -- 8. Statusline (lualine.nvim)
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lualine").setup({
                options = {
                    theme = "tokyonight",
                    component_separators = { left = "│", right = "│" },
                    section_separators = { left = "", right = "" },
                },
            })
        end,
    },

    -- 9. Git Signatures in Gutter (gitsigns.nvim)
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gitsigns").setup()
        end,
    },

    -- 10. Smart Commenting Utility (Comment.nvim)
    {
        "numToStr/Comment.nvim",
        config = function()
            require("Comment").setup()
        end,
    },

    -- 11. Auto-closing Brackets and Quotes (nvim-autopairs)
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = true,
    },

    -- 12. Floating Terminal Integration (toggleterm.nvim)
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        config = function()
            require("toggleterm").setup({
                size = 20,
                open_mapping = [[<C-\>]], -- Main keymap to toggle terminal: Ctrl + \
                hide_numbers = true,
                shade_terminals = true,
                shading_factor = 2,
                start_in_insert = true,
                insert_mappings = true,
                terminal_mappings = true,
                persist_size = true,
                persist_mode = true,
                direction = "float",     -- Floating window mode
                close_on_exit = true,
                shell = vim.o.shell,
                float_opts = {
                    border = "curved",   -- Border style: single, double, shadow, curved
                    winblend = 0,
                },
            })

            -- Terminal-specific keymaps
            local function set_terminal_keymaps()
                local opts = { buffer = 0 }
                -- Press Esc to switch from Terminal Insert mode to Terminal Normal mode
                vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)
                vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
                -- Navigate between splits/panes from terminal mode
                vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
                vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
                vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
                vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
            end

            -- Autocommand to apply terminal keymaps safely
            vim.api.nvim_create_autocmd("TermOpen", {
                pattern = "term://*toggleterm#*",
                callback = set_terminal_keymaps,
            })
        end,
    },
})
