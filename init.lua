--[[
=====================================================================
=====================================================================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=============== NOT A DISTRIBUTION BRO! =============================

MARKERS:
NOTE:
TODO:
WARN:
FIXME:
HACK:
DEBUG:
OPTIMIZE:
REVIEW:

If you don't know anything about Lua, https://learnxinyminutes.com/docs/lua/

After understanding a bit more about Lua, you can use `:help lua-guide` as a
reference for how Neovim integrates Lua.
- :help lua-guide
- (or HTML version): https://neovim.io/doc/user/lua-guide.html

--]]

-- [[ Set Leader Key ]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: Options have been moved to lua/options.lua
require("options")

-- NOTE: Keymaps have been moved to lua/keymaps.lua
require("keymaps")

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
desc = "Highlight when yanking (copying) text",
group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
callback = function()
vim.highlight.on_yank()
end,
})

-- [[ Install `lazy.nvim` plugin manager ]]

-- See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
local lazyrepo = "https://github.com/folke/lazy.nvim.git"
local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
if vim.v.shell_error ~= 0 then
error("Error cloning lazy.nvim:\n" .. out)
end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]

require("lazy").setup({
require("lazy-plugins"),
})

local harpoon = require("harpoon")

-- REQUIRED
harpoon:setup()
-- REQUIRED

vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end)
vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end)
vim.keymap.set("n", "<C-j>", function() harpoon:list():select(2) end)
vim.keymap.set("n", "<C-k>", function() harpoon:list():select(3) end)
vim.keymap.set("n", "<C-l>", function() harpoon:list():select(4) end)

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<C-S-P>", function() harpoon:list():prev() end)
vim.keymap.set("n", "<C-S-N>", function() harpoon:list():next() end)

local harpoon = require('harpoon')
harpoon:setup({})

-- basic telescope configuration
local conf = require("telescope.config").values
local function toggle_telescope(harpoon_files)
    local file_paths = {}
    for _, item in ipairs(harpoon_files.items) do
        table.insert(file_paths, item.value)
    end

    require("telescope.pickers").new({}, {
        prompt_title = "Harpoon",
        finder = require("telescope.finders").new_table({
            results = file_paths,
        }),
        previewer = conf.file_previewer({}),
        sorter = conf.generic_sorter({}),
    }):find()
end

vim.keymap.set("n", "<C-e>", function() toggle_telescope(harpoon:list()) end,
    { desc = "Open harpoon window" })

-- render - markdown commands
require('render-markdown').enable()
require('render-markdown').disable()

-- render-markdown Completion
require('render-markdown').setup({
    completions = { lsp = { enabled = true } },
})

-- Function to open Glow
local function open_glow()
    local file = vim.fn.expand("%:p") -- Get the current file path
    vim.cmd("!glow " .. file) -- Run Glow with the current file
end

-- Create a command to open Glow
vim.api.nvim_create_user_command("Glow", open_glow, {})

-- Optional: Create a key mapping to quickly open Glow
vim.api.nvim_set_keymap("n", "<leader>g", ":Glow<CR>", { noremap = true, silent = true })
-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
