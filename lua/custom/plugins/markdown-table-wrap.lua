-- In a rendered (Inline) table the cursor sits on the real row hidden under the
-- drawing, so free typing is disorienting. Read in Inline; <leader>tt to Source to
-- edit and back; or <leader>me to edit one cell in a float without leaving Inline.

-- Arrow keys move by table cell/row when the cursor is on a table line, and fall
-- back to plain cursor movement everywhere else. Normal-mode arrows otherwise only
-- duplicate hjkl, so this costs nothing.
local function in_table()
  return vim.api.nvim_get_current_line():match("^%s*|") ~= nil
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
    -- Render as an extmark layer over the real buffer, the same model as
    -- render-markdown. The plugin defaults to "reader", a separate protected
    -- buffer that is unlisted and rebinds normal-mode `y`/`d`.
    preview_mode = "inline",
    inline_mode = "replace",
    inline_wrap_scope = "always",
  },
  keys = {
    -- toggle (tables only; <leader>tm in render-markdown.lua does both)
    { "<leader>tt", "<cmd>MarkdownTableToggleInline<cr>", desc = "[T]oggle [T]able rendering", ft = "markdown" },

    -- <leader>m = [M]arkdown table editing
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
