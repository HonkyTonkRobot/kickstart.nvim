return { -- Highlight, edit, and navigate code
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- the main branch does not support lazy-loading
  build = ":TSUpdate",
  -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
  --
  -- The `main` branch only manages parser/query installation. Highlighting,
  -- indentation and folds are provided by Neovim itself and are enabled per
  -- buffer in the FileType autocmd below. Requires Neovim 0.11+ and the
  -- `tree-sitter` CLI (0.26.1+) on PATH to compile parsers.
  config = function()
    local ts = require("nvim-treesitter")
    ts.setup({})

    -- Parsers to always have installed. `install` is async and a no-op for
    -- parsers that are already present.
    ts.install({
      "bash",
      "c",
      "diff",
      "html",
      "lua",
      "luadoc",
      "markdown",
      "markdown_inline",
      "query",
      "vim",
      "vimdoc",
    })

    local function enable(buf, lang)
      vim.treesitter.start(buf, lang)
      -- Some languages depend on vim's regex indent rules (such as Ruby).
      if lang ~= "ruby" then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter-enable", { clear = true }),
      callback = function(ev)
        local lang = vim.treesitter.language.get_lang(ev.match)
        if not lang then
          return
        end
        if pcall(vim.treesitter.language.inspect, lang) then
          enable(ev.buf, lang)
          return
        end
        -- Autoinstall languages that are not installed yet, then enable.
        if not vim.tbl_contains(ts.get_available(), lang) then
          return
        end
        ts.install({ lang }):await(function()
          if vim.api.nvim_buf_is_valid(ev.buf) and pcall(vim.treesitter.language.inspect, lang) then
            enable(ev.buf, lang)
          end
        end)
      end,
    })
  end,
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects (main branch)
}
