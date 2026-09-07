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
}
