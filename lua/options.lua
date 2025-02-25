-- Options for Neovim configuration
--
-- NOTE: You can change these options as you wish!
-- For more options, you can see `:help option-list`

local opt = vim.opt

-- General settings
opt.encoding = 'utf-8'                -- Set character set to UTF-8
opt.fileformat = 'unix'               -- Set end of line character to LF
opt.shiftwidth = 2                     -- Set the number of spaces per indentation level
opt.tabstop = 2                        -- Set the number of spaces a tab counts for
opt.expandtab = true                   -- Use spaces instead of tabs
opt.autoindent = true                  -- Enable automatic indentation
opt.smartindent = true                 -- Enable smart indentation
-- opt.insert_final_newline = true      -- Remove or comment out this line

-- Trim trailing whitGespace on save for all file types
vim.cmd [[
  autocmd BufWritePre * :%s/\s\+$//e
]]

-- Do not trim trailing whitespace for Markdown files
vim.cmd [[
  autocmd BufWritePre *.md :let b:trim_whitespace = 0
]]

-- Enable line wrapping for LSP diagnostics
vim.opt.wrap = true
vim.opt.linebreak = true

-- Make line numbers default
opt.number = true
-- You can also add relative line numbers, to help with jumping.
-- Experiment for yourself to see if you like it!
opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
opt.showmode = false

-- Sync clipboard between OS and Neovim.
-- Schedule the setting after `UiEnter` because it can increase startup-time.
-- Remove this option if you want your OS clipboard to remain independent.
-- See `:help 'clipboard'`
vim.schedule(function()
  opt.clipboard = 'unnamedplus'
end)

-- Enable break indent
opt.breakindent = true

-- Save undo history
opt.undofile = true

-- Enable spell checking
opt.spell = true
opt.spelllang = { 'en_us' }
-- TODO: Figure out why the below line is not working
opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
opt.ignorecase = true
opt.smartcase = true

-- Keep signcolumn on by default
opt.signcolumn = 'yes'

-- Decrease update time
opt.updatetime = 250

-- Decrease mapped sequence wait time
opt.timeoutlen = 300

-- Configure how new splits should be opened
opt.splitright = true
opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
-- See `:help 'list'` and `:help 'listchars'`
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
opt.inccommand = 'split'

-- Show which line your cursor

-- Set which line starts page scrolling
opt.scrolloff = 8
