return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  ft = { 'markdown' },
  config = function()
    -- Disable initially to avoid C-call boundary error
    require('render-markdown').setup({
      enabled = false,  -- Start disabled
      completions = { lsp = { enabled = true } },
    })
    
    -- Enable after treesitter is fully ready
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function()
        vim.schedule(function()
          require('render-markdown').enable()
        end)
      end,
    })
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
  },
}