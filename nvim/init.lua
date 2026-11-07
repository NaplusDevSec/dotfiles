-- =====================================================================
-- Neovim Configuration for Low-Level C/Assembly Development (42 School friendly)
-- =====================================================================

-- ==========================================
-- 0. Machine-local settings (written by install.sh, not tracked in git)
-- ==========================================
-- ~/.config/nvim/local.lua returns a table, for example:
--     return { school42 = true, login = "jdoe", mail = "jdoe@student.42.fr" }
-- school42 = true  -> Norminette style (real tabs) and the 42 header
-- school42 = false (or no file) -> spaces, no 42 header
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

-- ==========================================
-- 1. Leader Keys Configuration
-- ==========================================
-- Set Space as the primary leader key for custom shortcuts
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ==========================================
-- 2. Core Editor Settings & Norminette Rules (Norminette part: 42 students only)
-- ==========================================
vim.opt.number = true            -- Show absolute line numbers
vim.opt.relativenumber = true    -- Show relative line numbers for fast jumping
vim.opt.cursorline = true        -- Highlight the current line
vim.opt.mouse = "a"              -- Enable full mouse support

-- Indentation: 42 Norminette needs real tabs of width 4; everyone else gets 4 spaces
vim.opt.tabstop = 4              -- Number of spaces that a Tab counts for
vim.opt.shiftwidth = 4           -- Size of an indent
vim.opt.expandtab = not school42 -- Real tabs for 42 (Norminette), spaces otherwise

-- Whitespace visualization
vim.opt.list = true
vim.opt.listchars = {
    tab = '▸-',                  -- Render Tab as arrow
    space = '·',                 -- Render Space as dot
    trail = '˽',                 -- Render trailing space
}

-- Custom Filetype Detection (x86 Assembly / MASM support)
vim.filetype.add({
    extension = {
        asm = "asm",
        inc = "asm",
    },
})

-- ==========================================
-- 3. Custom 42 Header Generator (Lua Native)
-- ==========================================
local function insert_42_header()
    local WIDTH = 80
    local filename = vim.fn.expand("%:t")
    local user = local_cfg.login or os.getenv("USER") or "user"
    local mail = local_cfg.mail or (user .. "@student.42.fr")
    local current_date = os.date("%Y/%m/%d %H:%M:%S")

    local function line(left, right)
        left = "/*   " .. left
        right = right .. " */"
        local pad = WIDTH - #left - #right
        if pad < 1 then pad = 1 end
        return left .. string.rep(" ", pad) .. right
    end

    local border = "/* " .. string.rep("*", WIDTH - 6) .. " */"

    -- Scan existing buffer to preserve the original 'Created:' date/user
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
        line("By: " .. user .. " <" .. mail .. ">", "+#+  +:+       +#+         "),
        line("", "+#+#+#+#+#+   +#+            "),
        line("Created: " .. created_date .. " by " .. created_user, "#+#    #+#             "),
        line("Updated: " .. current_date .. " by " .. user, "###   ########.fr      "),
        line("", ""),
        border,
        "",
    }

    -- Remove existing header before inserting updated one
    if #borders >= 2 and borders[1] == 1 then
        local last = borders[2]
        if scan[last + 1] == "" then last = last + 1 end
        vim.api.nvim_buf_set_lines(0, 0, last, false, {})
    end

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

-- Keymap and command for the 42 header (<Ctrl+Alt+h> or :Stdheader), 42 students only
if school42 then
    vim.keymap.set({ "n", "i" }, "<C-M-h>", insert_42_header, { desc = "Insert or update 42 Header" })
    vim.api.nvim_create_user_command("Stdheader", insert_42_header, {})
end

-- ==========================================
-- 4. Keybindings
-- ==========================================
-- Toggle file explorer with backtick key (`)
vim.keymap.set("n", "`", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle NvimTree" })

-- Jump to symbol definition via Ctrl + Left Click
vim.keymap.set("n", "<C-LeftMouse>", vim.lsp.buf.definition, { desc = "Go to LSP Definition" })

-- Toggle Markdown Preview in browser with <Space + m>
vim.keymap.set("n", "<leader>m", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })

-- Telescope Fuzzy Finder Keybindings
-- (required lazily: the plugin is not on the runtimepath until lazy.nvim loads it below)
local function telescope(picker)
    return function() require("telescope.builtin")[picker]() end
end
vim.keymap.set("n", "<leader>ff", telescope("find_files"), { desc = "Find files by name" })
vim.keymap.set("n", "<leader>fg", telescope("live_grep"), { desc = "Search text across project (grep)" })
vim.keymap.set("n", "<leader>fb", telescope("buffers"), { desc = "List open buffers" })
vim.keymap.set("n", "<leader>fh", telescope("help_tags"), { desc = "Search Neovim help tags" })

-- ==========================================
-- 5. Plugin Manager Setup (lazy.nvim)
-- ==========================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Configure Plugins
require("lazy").setup({
    -- 1. Syntax Highlighting (Treesitter)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = { "c", "lua", "vim", "vimdoc", "asm", "bash", "markdown", "markdown_inline" },
                highlight = { enable = true, additional_vim_regex_highlighting = false },
            })
        end,
    },

    -- 2. File Explorer Tree
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

    -- 3. Telescope Fuzzy Finder
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
            local lspconfig = require("lspconfig")
            lspconfig.clangd.setup({})
        end,
    },

    -- 5. Render Markdown inside Neovim buffers
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        opts = {},
        ft = { "markdown" },
    },

    -- 6. Live Browser Preview for Markdown
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = "cd app && npm install && git checkout -- .",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
    },
})
