-- Reader view: a markdown file with a table opens as a rendered, read-mostly copy.
-- You edit the table *by cell* from inside the rendered view rather than free-typing:
--   cic / dic / yic / vic  change / delete / yank / select the cell under the cursor
--   <leader>me             edit the cell in a small float (<C-s> save, Esc cancel)
--   arrows                 move by cell / row (below)
--   e, i, a, o ...         drop to the raw Source at the same spot for bigger edits;
--                          Reader reopens when you leave insert mode
--   q                      close Reader for this buffer and stay in Source
--   <leader>tt             toggle Reader <-> Source (<leader>tm also flips render-markdown)

-- Arrow keys move by table cell/row when the cursor is on a table line (raw `|` rows
-- in Source, box-drawn rows in Reader) and fall back to plain movement elsewhere.
-- Normal-mode arrows otherwise only duplicate hjkl, so this costs nothing.
local function in_table()
  return vim.api.nvim_get_current_line():match("^%s*[|│┃┌┐└┘├┤┬┴┼╭╮╰╯]") ~= nil
end

local function table_or(cmd, fallback)
  return function()
    if in_table() then
      vim.cmd(cmd)
    else
      vim.cmd.normal({ fallback, bang = true })
    end
  end
end

return {
  -- Wraps long cell contents inside rendered markdown tables so they fit the
  -- viewport. render-markdown.nvim cannot do this (upstream issue #616 is open),
  -- and normal `wrap` breaks the whole source row, which is what fragments the
  -- table borders.
  "ice345/markdown-table-wrap.nvim",
  ft = { "markdown" },
  opts = {
    -- Reader: a derived rendered buffer with cell-level editing (see the header
    -- comment). Inline "replace" was tried first; it hides the real row under a
    -- picture, so cursor movement, cell edits and keyword highlights were all
    -- invisible. Settings for a return to inline are kept below.
    preview_mode = "reader",
    reader = {
      auto_open = "has_table", -- plain prose files stay in Source
      sticky_header = true, -- header row stays visible on long tables
    },
    -- inline settings, only used if preview_mode is set back to "inline"
    inline_mode = "replace",
    inline_wrap_scope = "always",
  },
  keys = {
    -- toggle (tables only; <leader>tm in render-markdown.lua does both)
    { "<leader>tt", "<cmd>MarkdownTableTogglePreview<cr>", desc = "[T]oggle [T]able reader", ft = "markdown" },

    -- <leader>m = [M]arkdown table editing (work from Reader or Source)
    { "<leader>me", "<cmd>MarkdownTableEditCell<cr>", desc = "[E]dit cell in a float (<C-s> save, Esc cancel)", ft = "markdown" },
    { "<leader>mf", "<cmd>MarkdownTableFormat<cr>", desc = "[F]ormat / realign table", ft = "markdown" },
    { "<leader>mr", "<cmd>MarkdownTableAddRow<cr>", desc = "Add [r]ow below", ft = "markdown" },
    { "<leader>mR", "<cmd>MarkdownTableDeleteRow<cr>", desc = "Delete [R]ow", ft = "markdown" },
    { "<leader>mc", "<cmd>MarkdownTableAddColumn<cr>", desc = "Add [c]olumn after", ft = "markdown" },
    { "<leader>mC", "<cmd>MarkdownTableDeleteColumn<cr>", desc = "Delete [C]olumn", ft = "markdown" },
    { "<leader>mp", "<cmd>MarkdownTableFloatPreview<cr>", desc = "[P]review table in a float", ft = "markdown" },
    { "<leader>ms", "<cmd>MarkdownTableStatus<cr>", desc = "[S]tatus: which view am I in", ft = "markdown" },

    -- cell / row navigation on arrows, normal mode, markdown only
    { "<Right>", table_or("MarkdownTableNextCell", "l"), desc = "Next table cell", ft = "markdown" },
    { "<Left>", table_or("MarkdownTablePrevCell", "h"), desc = "Previous table cell", ft = "markdown" },
    { "<Down>", table_or("MarkdownTableNextRow", "j"), desc = "Next table row, same column", ft = "markdown" },
    { "<Up>", table_or("MarkdownTablePrevRow", "k"), desc = "Previous table row, same column", ft = "markdown" },
  },
}
