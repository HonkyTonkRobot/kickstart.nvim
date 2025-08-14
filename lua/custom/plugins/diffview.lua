return {
  "sindrets/diffview.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- optional, for icons
  },
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    -- Close Diff View
    { "<leader>gx",  "<cmd>DiffviewClose<cr><cmd>DiffviewClose<cr>",            desc = "[G]it Diff Close [x]" },
    -- Git Diff
    { "<leader>gd ", "<cmd>DiffviewClose<cr><cmd>DiffviewOpen<cr>",             desc = "[G]it [D]iff <Space>" },
    { "<leader>gds", "<cmd>DiffviewClose<cr><cmd>DiffviewOpen --cached<cr>",    desc = "[G]it [D]iff [S]taged" },
    { "<leader>gdh", "<cmd>DiffviewClose<cr><cmd>DiffviewOpen HEAD<cr>",        desc = "[G]it [D]iff [H]ead" },
    { "<leader>gdm", "<cmd>DiffviewClose<cr><cmd>DiffviewOpen main...HEAD<cr>", desc = "[G]it [D]iff [M]ain" },
    -- Git History
    { "<leader>gh",  "<cmd>DiffviewClose<cr><cmd>DiffviewFileHistory %<cr>",    desc = "[G]it [h]istory Current File" },
    { "<leader>gH",  "<cmd>DiffviewClose<cr><cmd>DiffviewFileHistory<cr>",      desc = "[G]it [H]istory" },
  },
  opts = function()
    local actions = require("diffview.actions")
    return {
      diff_binaries = false,
      enhanced_diff_hl = false,
      git_cmd = { "git" },
      hg_cmd = { "hg" },
      use_icons = true,
      show_help_hints = true,
      watch_index = true,
      icons = { folder_closed = "", folder_open = "" },
      signs = { fold_closed = "", fold_open = "", done = "✓" },

      view = {
        default = { layout = "diff2_horizontal", disable_diagnostics = false, winbar_info = false },
        merge_tool = { layout = "diff3_horizontal", disable_diagnostics = true, winbar_info = true },
        file_history = { layout = "diff2_horizontal", disable_diagnostics = false, winbar_info = false },
      },

      file_panel = {
        listing_style = "tree",
        tree_options = { flatten_dirs = true, folder_statuses = "only_folded" },
        win_config = { position = "left", width = 35, win_opts = {} },
      },

      file_history_panel = {
        log_options = {
          git = {
            single_file = { diff_merges = "combined" },
            multi_file = { diff_merges = "first-parent" },
          },
          hg = { single_file = {}, multi_file = {} },
        },
        win_config = { position = "bottom", height = 16, win_opts = {} },
      },

      commit_log_panel = { win_config = {} },
      default_args = { DiffviewOpen = {}, DiffviewFileHistory = {} },
      hooks = {},

      -- === paste your big keymaps table here unchanged ===
      keymaps = {
        disable_defaults = false,
        view = {
          { "n", "<tab>",      actions.select_next_entry,             { desc = "Open the diff for the next file" } },
          { "n", "<s-tab>",    actions.select_prev_entry,             { desc = "Open the diff for the previous file" } },
          { "n", "[F",         actions.select_first_entry,            { desc = "Open the first file" } },
          { "n", "]F",         actions.select_last_entry,             { desc = "Open the last file" } },
          { "n", "gf",         actions.goto_file_edit,                { desc = "Open the file in the previous tabpage" } },
          { "n", "<C-w><C-f>", actions.goto_file_split,               { desc = "Open the file in a new split" } },
          { "n", "<C-w>gf",    actions.goto_file_tab,                 { desc = "Open the file in a new tabpage" } },
          { "n", "<leader>e",  actions.focus_files,                   { desc = "[T]oggle [f]ocus file panel" } },
          { "n", "<leader>b",  actions.toggle_files,                  { desc = "[T]oggle Fil[e] panel" } },
          { "n", "g<C-x>",     actions.cycle_layout,                  { desc = "Cycle layouts" } },
          { "n", "[x",         actions.prev_conflict,                 { desc = "Prev conflict" } },
          { "n", "]x",         actions.next_conflict,                 { desc = "Next conflict" } },
          { "n", "<leader>co", actions.conflict_choose("ours"),       { desc = "Choose OURS" } },
          { "n", "<leader>ct", actions.conflict_choose("theirs"),     { desc = "Choose THEIRS" } },
          { "n", "<leader>cb", actions.conflict_choose("base"),       { desc = "Choose BASE" } },
          { "n", "<leader>ca", actions.conflict_choose("all"),        { desc = "Choose ALL" } },
          { "n", "dx",         actions.conflict_choose("none"),       { desc = "Delete conflict region" } },
          { "n", "<leader>cO", actions.conflict_choose_all("ours"),   { desc = "Choose OURS (file)" } },
          { "n", "<leader>cT", actions.conflict_choose_all("theirs"), { desc = "Choose THEIRS (file)" } },
          { "n", "<leader>cB", actions.conflict_choose_all("base"),   { desc = "Choose BASE (file)" } },
          { "n", "<leader>cA", actions.conflict_choose_all("all"),    { desc = "Choose ALL (file)" } },
          { "n", "dX",         actions.conflict_choose_all("none"),   { desc = "Delete conflict region (file)" } },
        },
        diff1 = { { "n", "g?", actions.help({ "view", "diff1" }), { desc = "Help" } }, },
        diff2 = { { "n", "g?", actions.help({ "view", "diff2" }), { desc = "Help" } }, },
        diff3 = {
          { { "n", "x" }, "2do", actions.diffget("ours"),           { desc = "Get hunk from OURS" } },
          { { "n", "x" }, "3do", actions.diffget("theirs"),         { desc = "Get hunk from THEIRS" } },
          { "n",          "g?",  actions.help({ "view", "diff3" }), { desc = "Help" } },
        },
        diff4 = {
          { { "n", "x" }, "1do", actions.diffget("base"),           { desc = "Get hunk from BASE" } },
          { { "n", "x" }, "2do", actions.diffget("ours"),           { desc = "Get hunk from OURS" } },
          { { "n", "x" }, "3do", actions.diffget("theirs"),         { desc = "Get hunk from THEIRS" } },
          { "n",          "g?",  actions.help({ "view", "diff4" }), { desc = "Help" } },
        },
        -- keep your file_panel / file_history_panel / option_panel / help_panel blocks here exactly as you had them
      },
    }
  end,
  config = function(_, opts)
    require("diffview").setup(opts)
  end,
}