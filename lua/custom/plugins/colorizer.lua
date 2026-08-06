return {
  "uga-rosa/ccc.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    highlighter = {
      auto_enable = true,   -- turn on color highlights automatically
      lsp = true,           -- use LSP color provider if available (e.g. cssls)
    },
  },
  keys = {
    { "<leader>cp", "<Cmd>CccPick<CR>", desc = "Pick color" },
  },
}
