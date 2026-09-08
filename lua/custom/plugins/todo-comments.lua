return {
  "folke/todo-comments.nvim",
  event = "VimEnter",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    signs = false,
    -- Review prefixes used in the bws change registers (Joel column / notes):
    --   Q: question for Claude   ASK: becomes a client question   FIX: data is wrong (default keyword)
    --   SIZE: disagree with the credits   JV: needs JV's call
    keywords = {
      Q = { icon = "? ", color = "info" },
      ASK = { icon = "→ ", color = "hint" },
      SIZE = { icon = "# ", color = "warning" },
      JV = { icon = "J ", color = "jv" },
    },
    colors = {
      jv = { "DiagnosticError", "#e0af68" },
    },
    highlight = {
      -- markdown has no comment nodes; highlight the prefixes anywhere, not only in comments
      comments_only = false,
      -- colour just the keyword, not the rest of the line (otherwise a whole table row lights up)
      after = "",
      -- keyword followed by a colon; the word boundary stops FAQ: or jv: in prose matching
      pattern = [[.*<(KEYWORDS)\s*:]],
    },
    search = {
      pattern = [[\b(KEYWORDS):]],
    },
  },
}
