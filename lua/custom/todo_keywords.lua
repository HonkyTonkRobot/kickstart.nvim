-- Review keywords (Q:, ASK:, FIX:, NOTE: ...) in markdown.
--
-- todo-comments highlights one keyword per line, and its greedy `.*<(KEYWORDS):` pattern picks
-- the last one, so `FIX: a JV: b` only lit up JV. Markdown is excluded from its highlighter and
-- this module colours every `KEYWORD:` on a line instead (ephemeral extmarks from a decoration
-- provider, so nothing to clean up). The keyword -> group map comes from todo-comments' own
-- config, alternates included (FIXME -> TodoBgFIX, INFO -> TodoBgNOTE). wrapped_tables uses
-- the same scanner for rendered cells.
local M = {}

---Keyword -> highlight group for every todo-comments keyword. Empty until the plugin has run
---its (deferred) setup.
function M.groups()
  local groups = {}
  local ok, cfg = pcall(require, "todo-comments.config")
  if ok and type(cfg.keywords) == "table" then
    for alt, main in pairs(cfg.keywords) do
      groups[alt] = "TodoBg" .. main
    end
  end
  return groups
end

---Next `KEYWORD:` in `text` at or after byte `init`: a word-start run of capitals, optional
---space, colon. Returns start, finish (inclusive, 1-based) and the highlight group, or nil.
---Unknown words (FAQ:) are skipped over.
function M.find(text, init, groups)
  groups = groups or M.groups()
  local j = init or 1
  while j <= #text do
    local s, e, kw = text:find("%f[%w](%u+)%s*:", j)
    if not s then
      return nil
    end
    local grp = groups[kw]
    if grp then
      return s, e, vim.fn.hlexists(grp) == 1 and grp or "Todo"
    end
    j = e + 1
  end
end

local ns = vim.api.nvim_create_namespace("custom_todo_keywords")

function M.setup()
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, buf)
      return vim.bo[buf].filetype == "markdown"
    end,
    on_line = function(_, _, buf, row)
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      if not line or not line:find(":", 1, true) then
        return
      end
      local groups = M.groups()
      local j = 1
      while true do
        local s, e, grp = M.find(line, j, groups)
        if not s then
          break
        end
        vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, { end_col = e, hl_group = grp, ephemeral = true })
        j = e + 1
      end
    end,
  })
end

return M
