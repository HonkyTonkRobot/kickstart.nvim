return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  ft = { 'markdown' },
  opts = {
    -- Tables are rendered by markdown-table-wrap.nvim, which can wrap long
    -- cells to the viewport. This is that plugin's documented coexistence
    -- setting; everything else here still renders normally.
    pipe_table = { enabled = false },
    completions = { lsp = { enabled = true } },
  },
  keys = {
    {
      '<leader>tm',
      function()
        require('render-markdown').toggle()
      end,
      desc = '[T]oggle [M]arkdown rendering',
      ft = 'markdown',
    },
  },
}
