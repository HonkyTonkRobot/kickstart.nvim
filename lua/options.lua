-- Options for Neovim configuration
--
-- NOTE: You can change these options as you wish!
-- For more options, you can see `:help option-list`
vim.o.encoding = 'utf-8'                -- Set character set to UTF-8
vim.opt.fileformat = 'unix'               -- Set end of line character to LF
vim.o.shiftwidth = 2                     -- Set the number of spaces per indentation level
vim.o.tabstop = 2                        -- Set the number of spaces a tab counts for
vim.o.expandtab = true                   -- Use spaces instead of tabs
vim.o.autoindent = true                  -- Enable automatic indentation
vim.o.smartindent = true                 -- Enable smart indentation
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
vim.o.wrap = true
vim.o.linebreak = true

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
-- Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
-- Schedule the setting after `UiEnter` because it can increase startup-time.
-- Remove this option if you want your OS clipboard to remain independent.
-- See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Enable spell checking
vim.o.spell = true
vim.opt.spelllang = { 'en_us' }
-- TODO: Figure out why the below line is not working
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
-- See `:help 'list'` and `:help 'listchars'`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor
vim.o.cursorline = false

-- Set which line starts page scrolling
vim.o.scrolloff = 8

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true
