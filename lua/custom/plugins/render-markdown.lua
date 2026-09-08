-- Markdown rendering, including wrapped, in-place-editable tables.
--
-- Tables are drawn by lua/custom/wrapped_tables.lua as a render-markdown custom handler:
-- long cells wrap, one line number per row, the row under the cursor shows raw so you
-- type straight into it, every other row stays rendered. Read that file's header for how.
--
-- Table keys (markdown buffers):
--   <leader>tt    lock on (default): tables stay rendered under the cursor, the cursor is hidden
--                 and the current cell highlighted, hjkl move by cell / row, i / a insert at the
--                 start / end of that cell (the row reveals itself while typing).
--                 lock off: cursor row shows raw, hjkl are normal motions.
--   arrows        move by cell / row when on a table line in either mode
--   Enter         on a table row: edit the cell in a float (Enter or :q saves and exits, :q! discards)
--   <leader>me    same as Enter
--   <leader>mf    realign the raw table      <leader>mr / mR   add / delete row
--   <leader>mc / mC  add / delete column     <leader>tm        toggle all rendering
local function wt()
  return require('custom.wrapped_tables')
end

return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  ---@module 'render-markdown'
  ft = { 'markdown' },
  opts = function()
    ---@type render.md.UserConfig
    return {
      -- Render in every mode; anti-conceal keeps only the cursor row raw, even in insert.
      render_modes = true,
      -- The builtin table renderer cannot wrap cells; wrapped_tables replaces it.
      pipe_table = { enabled = false },
      custom_handlers = {
        markdown = { extends = true, parse = wt().parse_markdown },
        -- builtin inline marks (links, code spans) minus table rows, which wrapped_tables draws
        markdown_inline = { extends = false, parse = wt().parse_inline },
      },
      completions = { lsp = { enabled = true } },
    }
  end,
  config = function(_, opts)
    require('render-markdown').setup(opts)
    -- locked tables re-render on cursor-cell and mode changes (render-markdown alone only
    -- re-runs handlers when the text changes)
    wt().setup()
  end,
  keys = {
    {
      '<leader>tm',
      function()
        require('render-markdown').toggle()
      end,
      desc = '[T]oggle [M]arkdown rendering',
      ft = 'markdown',
    },
    { '<leader>tt', function() wt().toggle_lock() end, desc = '[T]oggle [T]able lock (rendered under cursor)', ft = 'markdown' },
    -- i / a on a locked table row: insert at the start / end of the highlighted cell
    { 'i', function() wt().insert('i')() end, desc = 'Insert (at cell start on a locked table)', ft = 'markdown' },
    { 'a', function() wt().insert('a')() end, desc = 'Append (at cell end on a locked table)', ft = 'markdown' },
    -- hjkl: by cell / row on a locked table, normal motions otherwise
    { 'h', function() wt().hjkl('h')() end, desc = 'Left / previous table cell', ft = 'markdown' },
    { 'l', function() wt().hjkl('l')() end, desc = 'Right / next table cell', ft = 'markdown' },
    { 'j', function() wt().hjkl('j')() end, desc = 'Down / next table row', ft = 'markdown' },
    { 'k', function() wt().hjkl('k')() end, desc = 'Up / previous table row', ft = 'markdown' },
    { '<CR>', function() wt().enter() end, desc = 'Edit table cell in a float / plain Enter', ft = 'markdown' },
    -- <leader>m = [M]arkdown table editing
    { '<leader>me', function() wt().edit_cell() end, desc = '[E]dit cell in a float (:q save, :q! discard)', ft = 'markdown' },
    { '<leader>mf', function() wt().format() end, desc = '[F]ormat / realign raw table', ft = 'markdown' },
    { '<leader>mr', function() wt().add_row() end, desc = 'Add [r]ow below', ft = 'markdown' },
    { '<leader>mR', function() wt().delete_row() end, desc = 'Delete [R]ow', ft = 'markdown' },
    { '<leader>mc', function() wt().add_column() end, desc = 'Add [c]olumn after', ft = 'markdown' },
    { '<leader>mC', function() wt().delete_column() end, desc = 'Delete [C]olumn', ft = 'markdown' },
    -- cell / row navigation on arrows, normal mode, markdown only
    { '<Right>', function() wt().on_table_or(wt().next_cell, 'l')() end, desc = 'Next table cell', ft = 'markdown' },
    { '<Left>', function() wt().on_table_or(wt().prev_cell, 'h')() end, desc = 'Previous table cell', ft = 'markdown' },
    { '<Down>', function() wt().on_table_or(wt().next_row, 'j')() end, desc = 'Next table row, same column', ft = 'markdown' },
    { '<Up>', function() wt().on_table_or(wt().prev_row, 'k')() end, desc = 'Previous table row, same column', ft = 'markdown' },
  },
}
