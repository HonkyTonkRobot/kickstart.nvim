return {
  "lewis6991/gitsigns.nvim",
  opts = {
    on_attach = function(bufnr)
      local gitsigns = require 'gitsigns'

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map('n', '<leader>gn', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gitsigns.nav_hunk 'next'
        end
      end, { desc = 'Jump to [n]ext git change' })

      map('n', '<leader>gp', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gitsigns.nav_hunk 'prev'
        end
      end, { desc = 'Jump to [p]revious git change' })

      -- Actions
      -- visual mode
      map('v', '<leader>gs', function()
        gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, { desc = 'git [s]tage hunk' })
      map('v', '<leader>gr', function()
        gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, { desc = 'git [r]eset hunk' })
      -- normal mode
      map('n', '<leader>gs', gitsigns.stage_hunk, { desc = '[G]it [s]tage hunk' })
      map('n', '<leader>gr', gitsigns.reset_hunk, { desc = '[G]it [r]eset hunk' })
      map('n', '<leader>gS', gitsigns.stage_buffer, { desc = '[G]it [S]tage buffer' })
      map('n', '<leader>gu', gitsigns.stage_hunk, { desc = '[G]it [u]ndo stage hunk' })
      map('n', '<leader>gR', gitsigns.reset_buffer, { desc = '[G]it [R]eset buffer' })
      map('n', '<leader>gv', gitsigns.preview_hunk, { desc = '[G]it [v]iew hunk' })
      map('n', '<leader>gb', gitsigns.blame_line, { desc = '[G]it [b]lame line' })
      map('n', '<leader>gdl', gitsigns.diffthis, { desc = '[G]it [d]iff against index' })
      map('n', '<leader>gdt', function()
        gitsigns.diffthis '@'
      end, { desc = '[G]it [D]iff against last commit' })
      -- Toggles
      map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
      map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = '[T]oggle git show [D]eleted' })
    end,
  },
}