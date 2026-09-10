-- Review prefixes used in the bws change registers (Joel column / notes):
--   Q: question for Claude   ASK: becomes a client question   FIX: data is wrong (default keyword)
--   SIZE: disagree with the credits   JV: needs JV's call
-- <leader>st = [S]earch [T]odos. Each key opens the Telescope picker pre-filtered to one keyword set,
-- searching from nvim's working directory (open nvim at the repo root for repo-wide results).
-- <leader>n = [N]ote prefix. Same letters as <leader>st: types "KW: " at the cursor and leaves you in
-- insert mode (appends when the cursor is on the last character of the line, inserts otherwise).
local function starter(kw)
  return function()
    local col, last = vim.fn.col("."), vim.fn.col("$") - 1
    local key = (last > 0 and col >= last) and "a" or "i"
    vim.api.nvim_feedkeys(key .. kw .. ": ", "n", false)
  end
end

return {
  "folke/todo-comments.nvim",
  event = "VimEnter",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>stt", "<cmd>TodoTelescope<cr>", desc = "[T]odos: everything" },
    { "<leader>stm", "<cmd>TodoTelescope keywords=Q,ASK,FIX,SIZE,JV<cr>", desc = "[M]ine: Q, ASK, FIX, SIZE, JV" },
    { "<leader>stq", "<cmd>TodoTelescope keywords=Q<cr>", desc = "[Q]: questions for Claude" },
    { "<leader>sta", "<cmd>TodoTelescope keywords=ASK<cr>", desc = "[A]SK: for the client" },
    { "<leader>stf", "<cmd>TodoTelescope keywords=FIX<cr>", desc = "[F]IX: data is wrong (+ FIXME/BUG)" },
    { "<leader>sts", "<cmd>TodoTelescope keywords=SIZE<cr>", desc = "[S]IZE: disagree with credits" },
    { "<leader>stj", "<cmd>TodoTelescope keywords=JV<cr>", desc = "[J]V: needs JV's call" },
    -- the stock code keywords
    { "<leader>sto", "<cmd>TodoTelescope keywords=TODO<cr>", desc = "T[O]DO" },
    { "<leader>sth", "<cmd>TodoTelescope keywords=HACK<cr>", desc = "[H]ACK" },
    { "<leader>stw", "<cmd>TodoTelescope keywords=WARN<cr>", desc = "[W]ARN / XXX" },
    { "<leader>stp", "<cmd>TodoTelescope keywords=PERF<cr>", desc = "[P]ERF" },
    { "<leader>stn", "<cmd>TodoTelescope keywords=NOTE<cr>", desc = "[N]OTE / INFO" },
    { "<leader>ste", "<cmd>TodoTelescope keywords=TEST<cr>", desc = "T[E]ST" },
    -- note starters: type the prefix and drop into insert mode
    { "<leader>nq", starter("Q"), desc = "[Q]: question for Claude" },
    { "<leader>na", starter("ASK"), desc = "[A]SK: for the client" },
    { "<leader>nf", starter("FIX"), desc = "[F]IX: data is wrong" },
    { "<leader>ns", starter("SIZE"), desc = "[S]IZE: disagree with credits" },
    { "<leader>nj", starter("JV"), desc = "[J]V: needs JV's call" },
    { "<leader>no", starter("TODO"), desc = "T[O]DO" },
    { "<leader>nh", starter("HACK"), desc = "[H]ACK" },
    { "<leader>nw", starter("WARN"), desc = "[W]ARN" },
    { "<leader>np", starter("PERF"), desc = "[P]ERF" },
    { "<leader>nn", starter("NOTE"), desc = "[N]OTE" },
    { "<leader>ne", starter("TEST"), desc = "T[E]ST" },
  },
  opts = {
    signs = false,
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
