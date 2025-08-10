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
- :help lua-guide (or HTML version): https://neovim.io/doc/user/lua-guide.html
--]]

-- [[ Set Leader Key ]]

--
--  NOTE: Set <space> as the leader key (Must happen before plugins are loaded)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]

-- lua/options.lua
require("options")

-- lua/keymaps.lua
require("keymaps")

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
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

-- render - markdown commands
require('render-markdown').enable()
require('render-markdown').disable()

-- render-markdown Completion
require('render-markdown').setup({
    completions = { lsp = { enabled = true } },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
