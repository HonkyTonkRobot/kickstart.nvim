-- Wrapped pipe tables for render-markdown.nvim.
--
-- Why this exists: render-markdown draws tables but cannot wrap long cells (upstream
-- #616), and every table plugin that wraps does it by painting virtual text over the
-- real row, which hides what the cursor is on. This handler wraps cells and keeps the
-- row editable: the row under the cursor shows raw (render-markdown's anti-conceal),
-- every other row is drawn wrapped, one line number per row.
--
-- How a row is drawn: nvim wraps a concealed line by its raw width (and honours
-- 'linebreak'), so a long hidden row still occupies ceil(raw / width) screen rows.
-- Rendered line i is placed as an overlay at the byte where wrap row i starts; any
-- rendered lines beyond the raw row's own height go in virt_lines below it; if the
-- raw row is taller than the rendered one, the spare rows get empty cell lines so
-- nothing gaps. wrap_starts() reproduces nvim's wrap points including 'linebreak'.
--
-- Lock (M.locked, <leader>tt, default on): tables stay rendered even under the cursor.
-- The cursor itself is hidden there and the cell it is in is highlighted; hjkl move by
-- cell/row; i / a insert at the start / end of that cell; entering insert (or visual)
-- mode reveals the row so you can see what you type and Esc re-locks it. With
-- the lock off the cursor row shows raw (hover mode) and hjkl are normal motions. Arrow
-- keys move by cell/row on a table in both modes.
--
-- Also here: the cell-level editing commands the arrow keys, hjkl and <leader>m bind to
-- (next/prev cell and row, edit cell in a float, add/delete row and column, format),
-- so no separate table plugin is needed.

local M = {}

M.opts = {
  min_col = 6, -- never squeeze a column narrower than this
  prefixes = { "Q", "ASK", "FIX", "SIZE", "JV" }, -- review keywords coloured inside rendered cells
  hl = {
    head = "RenderMarkdownTableHead",
    row = "RenderMarkdownTableRow",
    text = "Normal",
    link = "RenderMarkdownLink",
    code = "RenderMarkdownCodeInline",
    bold = "Bold",
    cursor_cell = "WrappedTableCursorCell",
  },
}

-- tables stay rendered under the cursor; <leader>tt flips this for the session
M.locked = true

vim.api.nvim_set_hl(0, "WrappedTableCursorCell", { link = "Visual", default = true })
-- fully transparent cursor, used while in normal mode on a locked table row so only the
-- highlighted cell shows where you are
vim.api.nvim_set_hl(0, "WrappedTableHiddenCursor", { blend = 100, nocombine = true })

-- ---------------------------------------------------------------- text helpers

local strwidth = vim.fn.strdisplaywidth

local UTF8 = "[%z\1-\127\194-\244][\128-\191]*"

---Iterate utf8 characters: returns list of { ch, w } with byte start (1-based) in [3].
local function chars(s)
  local out = {}
  for ch in s:gmatch(UTF8) do
    out[#out + 1] = { ch, strwidth(ch) }
  end
  local b = 1
  for _, c in ipairs(out) do
    c[3] = b
    b = b + #c[1]
  end
  return out
end

local function isbreak(ch)
  return #ch == 1 and vim.o.breakat:find(ch, 1, true) ~= nil
end

---Byte offsets (0-based) where each screen row of `s` starts when displayed in a window
---`width` cells wide with 'wrap' on, reproducing nvim's 'linebreak' rule: at a breakat
---character followed by a non-breakat one, if the following word (plus its trailing
---breakat run) does not fit on the current row, the breakat character is padded to the
---row end and the word starts the next row.
---@param s string
---@param width integer
---@param linebreak boolean
---@return integer[]
function M.wrap_starts(s, width, linebreak)
  local cs = chars(s)
  local n = #cs
  local starts = { 0 }
  if n == 0 or width <= 0 then
    return starts
  end
  -- 'linebreak' is not applied inside the leading breakat run
  local lead = 1
  while lead <= n and isbreak(cs[lead][1]) do
    lead = lead + 1
  end
  local col = 0
  for i = 1, n do
    local ch, w = cs[i][1], cs[i][2]
    local size = w
    if linebreak and i >= lead and i < n and isbreak(ch) and not isbreak(cs[i + 1][1]) then
      local col2 = col
      local first = true
      local j = i + 1
      while j <= n do
        local cj, pj = cs[j][1], cs[j - 1][1]
        local cont = isbreak(cj) or (not isbreak(cj) and (first or not isbreak(pj)))
        if not cont then
          break
        end
        first = false
        col2 = col2 + cs[j][2]
        if col2 >= width then
          size = width - col -- pad to the row end; the word goes to the next row
          break
        end
        j = j + 1
      end
    end
    if col + size > width and col > 0 then
      starts[#starts + 1] = cs[i][3] - 1
      col = 0
      size = w
    end
    col = col + size
    if col >= width and i < n then
      starts[#starts + 1] = cs[i + 1][3] - 1
      col = 0
    end
  end
  return starts
end

---Split a raw table row into cell strings (unescaped `\|` kept escaped) plus the byte
---spans of each cell's content between the pipes. Returns cells, spans where
---spans[i] = { start_col, end_col } 0-based, end exclusive, of the trimmed content.
function M.split_row(line)
  local pipes = {}
  local i = 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" then
      i = i + 2
    else
      if c == "|" then
        pipes[#pipes + 1] = i
      end
      i = i + 1
    end
  end
  if #pipes < 2 then
    return nil
  end
  local cells, spans, inner = {}, {}, {}
  for k = 1, #pipes - 1 do
    local a, b = pipes[k] + 1, pipes[k + 1] - 1
    local raw = line:sub(a, b)
    local ls = raw:match("^%s*()")
    local le = raw:match("()%s*$", ls) -- from ls, so an all-space cell gives an empty span, not an inverted one
    local text = raw:sub(ls, le - 1)
    cells[#cells + 1] = text
    spans[#spans + 1] = { a - 1 + ls - 1, a - 1 + le - 1 }
    inner[#inner + 1] = { a - 1, b } -- everything between the two pipes, padding included
  end
  return cells, spans, inner
end

---Turn cell markdown into highlighted chunks: strips link targets, code ticks, bold
---markers and pipe escapes; colours a leading review prefix with its todo-comments group.
---@return { [1]: string, [2]: string }[]
function M.clean(text)
  local hl = M.opts.hl
  local chunks = {}
  local function push(t, h)
    if t ~= "" then
      chunks[#chunks + 1] = { t, h }
    end
  end
  text = text:gsub("\\|", "|")
  -- review prefix at the start of the cell
  for _, kw in ipairs(M.opts.prefixes) do
    local rest = text:match("^" .. kw .. ":%s*(.*)$")
    if rest then
      local grp = "TodoBg" .. kw
      push(kw .. ":", vim.fn.hlexists(grp) == 1 and grp or "Todo")
      push(" ", hl.text)
      text = rest
      break
    end
  end
  local i = 1
  while i <= #text do
    local ls, le, label = text:find("^%[([^%]]-)%]%(.-%)", i)
    if ls then
      push(label, hl.link)
      i = le + 1
    else
      local cs, ce, code = text:find("^`([^`]-)`", i)
      if cs then
        push(code, hl.code)
        i = ce + 1
      else
        local bs, be, bold = text:find("^%*%*(.-)%*%*", i)
        if bs then
          push(bold, hl.bold)
          i = be + 1
        else
          -- plain run up to the next special character
          local ns = text:find("[%[`%*]", i + 1) or (#text + 1)
          push(text:sub(i, ns - 1), hl.text)
          i = ns
        end
      end
    end
  end
  return chunks
end

local function chunks_width(chunks)
  local w = 0
  for _, c in ipairs(chunks) do
    w = w + strwidth(c[1])
  end
  return w
end

---Word-wrap highlighted chunks to `width` cells. Returns a list of lines, each a list
---of chunks. Words longer than the width are split.
function M.wrap_chunks(chunks, width)
  -- explode into words carrying their highlight
  local words = {}
  for _, c in ipairs(chunks) do
    for word, space in c[1]:gmatch("(%S*)(%s*)") do
      if word ~= "" then
        words[#words + 1] = { word, c[2], space ~= "" }
      elseif space ~= "" and #words > 0 then
        words[#words][3] = true
      end
    end
  end
  local lines, cur, col = {}, {}, 0
  local function flush()
    lines[#lines + 1] = cur
    cur, col = {}, 0
  end
  for _, w in ipairs(words) do
    local text, h, sp = w[1], w[2], w[3]
    local tw = strwidth(text)
    if col > 0 and col + tw > width then
      flush()
    end
    while tw > width do -- hard split an over-long word
      local cut, acc = 0, 0
      for ch in text:gmatch(UTF8) do
        local cw = strwidth(ch)
        if acc + cw > width then
          break
        end
        acc = acc + cw
        cut = cut + #ch
      end
      cur[#cur + 1] = { text:sub(1, cut), h }
      flush()
      text = text:sub(cut + 1)
      tw = strwidth(text)
    end
    cur[#cur + 1] = { text, h }
    col = col + tw
    if sp and col < width then
      cur[#cur + 1] = { " ", h }
      col = col + 1
    end
  end
  if #cur > 0 or #lines == 0 then
    flush()
  end
  -- drop trailing spaces on each line
  for _, l in ipairs(lines) do
    local last = l[#l]
    if last and last[1] == " " then
      l[#l] = nil
    end
  end
  return lines
end

-- ---------------------------------------------------------------- table model

local function is_row(l)
  return l and l:match("^%s*|") ~= nil
end

---Build a table model from the raw lines `first..last` (0-based rows); `slice` holds
---exactly those lines. `lines` in the result is indexed by absolute row + 1 like a
---buffer, so callers can use tbl.lines[r + 1] for any r in first..last.
---@return { first: integer, last: integer, header: integer, delim: integer, rows: integer[], ncols: integer, lines: table<integer, string> }?
function M.table_from_lines(slice, first)
  local last = first + #slice - 1
  local lines = {}
  for i, l in ipairs(slice) do
    lines[first + i] = l
  end
  local delim
  for r = first, last do
    local l = lines[r + 1]
    if l:match("^%s*|[%s:%-|]+|%s*$") and l:find("%-") then
      delim = r
      break
    end
  end
  if not delim or delim == first then
    return nil
  end
  local body = {}
  for r = delim + 1, last do
    body[#body + 1] = r
  end
  local cells = M.split_row(lines[first + 1])
  return { first = first, last = last, header = first, delim = delim, rows = body, ncols = cells and #cells or 0, lines = lines }
end

---Parse the table containing `row` (0-based) in `buf` by scanning for the pipe rows
---around it. Returns nil if none. Used by the editing commands.
function M.table_at(buf, row)
  local n = vim.api.nvim_buf_line_count(buf)
  local function line(r)
    return vim.api.nvim_buf_get_lines(buf, r, r + 1, false)[1]
  end
  if not is_row(line(row)) then
    return nil
  end
  local first, last = row, row
  while first > 0 and is_row(line(first - 1)) do
    first = first - 1
  end
  while last + 1 < n and is_row(line(last + 1)) do
    last = last + 1
  end
  return M.table_from_lines(vim.api.nvim_buf_get_lines(buf, first, last + 1, false), first)
end

---Column widths for a table given the available inner width.
local function column_widths(natural, avail, min_col)
  local total = 0
  for _, w in ipairs(natural) do
    total = total + w
  end
  if total <= avail then
    return natural
  end
  -- water-fill: columns narrower than the cap keep their width, the rest share the remainder
  local order = {}
  for i, w in ipairs(natural) do
    order[#order + 1] = { i, w }
  end
  table.sort(order, function(a, b)
    return a[2] < b[2]
  end)
  local widths = {}
  local remaining, left = avail, #natural
  for _, o in ipairs(order) do
    local cap = math.floor(remaining / left)
    -- a column never grows past its natural width; a squeezed one never drops below min_col
    local w = math.min(o[2], math.max(min_col, cap))
    widths[o[1]] = w
    remaining = remaining - w
    left = left - 1
  end
  return widths
end

-- ---------------------------------------------------------------- render-markdown handler

local ts_query -- parsed lazily

local function window_for(buf)
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= buf then
    win = vim.fn.bufwinid(buf)
  end
  if win == -1 then
    return nil
  end
  return win
end

local function text_width(win)
  local info = vim.fn.getwininfo(win)[1]
  return vim.api.nvim_win_get_width(win) - (info and info.textoff or 0)
end

local BOX = { h = "─", v = "│", tl = "┌", tr = "┐", bl = "└", br = "┘", t = "┬", b = "┴", l = "├", r = "┤", x = "┼" }

---Build the rendered lines for one table. `cursor` = { row, cell } highlights that cell.
---@return table<integer, { lines: { [1]: string, [2]: string }[][] }> per row, plus borders
local function layout(tbl, W, cursor)
  local hl = M.opts.hl
  local ncols = tbl.ncols
  local rows = { tbl.header }
  vim.list_extend(rows, tbl.rows)
  -- clean cells and natural widths
  local cleaned, natural = {}, {}
  for _, r in ipairs(rows) do
    local cells = M.split_row(tbl.lines[r + 1]) or {}
    local cc = {}
    for c = 1, ncols do
      cc[c] = M.clean(cells[c] or "")
      natural[c] = math.max(natural[c] or 0, chunks_width(cc[c]), 1)
    end
    cleaned[r] = cc
  end
  local avail = W - (ncols + 1) - 2 * ncols
  local widths = column_widths(natural, math.max(avail, ncols * M.opts.min_col), M.opts.min_col)

  local function border(l, m, r, grp)
    local parts = { { l, grp } }
    for c = 1, ncols do
      parts[#parts + 1] = { string.rep(BOX.h, widths[c] + 2), grp }
      parts[#parts + 1] = { c < ncols and m or r, grp }
    end
    return parts
  end

  local out = { rows = {}, top = border(BOX.tl, BOX.t, BOX.tr, hl.head), mid = border(BOX.l, BOX.x, BOX.r, hl.row), bottom = border(BOX.bl, BOX.b, BOX.br, hl.row) }
  for _, r in ipairs(rows) do
    local is_head = r == tbl.header
    local grp = is_head and hl.head or hl.row
    local wrapped, k = {}, 1
    for c = 1, ncols do
      wrapped[c] = M.wrap_chunks(cleaned[r][c], widths[c])
      k = math.max(k, #wrapped[c])
    end
    local lines = {}
    for i = 1, k do
      local parts = { { BOX.v, grp } }
      for c = 1, ncols do
        parts[#parts + 1] = { " ", grp }
        local cell = wrapped[c][i] or {}
        local used = 0
        local here = cursor and cursor.row == r and cursor.cell == c
        for _, ch in ipairs(cell) do
          parts[#parts + 1] = { ch[1], here and hl.cursor_cell or (is_head and hl.head or ch[2]) }
          used = used + strwidth(ch[1])
        end
        parts[#parts + 1] = { string.rep(" ", widths[c] - used + 1), here and hl.cursor_cell or grp }
        parts[#parts + 1] = { BOX.v, grp }
      end
      lines[i] = parts
    end
    out.rows[r] = lines
  end
  -- an empty cell line, used to fill spare wrap rows
  local empty = { { BOX.v, hl.row } }
  for c = 1, ncols do
    empty[#empty + 1] = { string.rep(" ", widths[c] + 2), hl.row }
    empty[#empty + 1] = { BOX.v, hl.row }
  end
  out.empty = empty
  return out
end

---render-markdown custom handler for the `markdown` language.
---@param ctx { buf: integer, root: TSNode, last: boolean }
---@return table[]
-- Per-buffer cache of rendered marks keyed by the table's start row, text, width and
-- linebreak setting: a cursor move or a keystroke elsewhere costs nothing for tables
-- that did not change.
local cache = setmetatable({}, { __mode = "k" })

---@param keep integer? row whose marks must survive the cursor (locked mode): conceal=false
local function table_marks(tbl, W, linebreak, cursor, keep)
  local marks = {}
  local L = layout(tbl, W, cursor)
  local ordered = { tbl.header, tbl.delim }
  vim.list_extend(ordered, tbl.rows)
  for idx, r in ipairs(ordered) do
        local raw = tbl.lines[r + 1]
        local lines = r == tbl.delim and { L.mid } or L.rows[r]
        local starts = M.wrap_starts(raw, W, linebreak)
        local hide = r ~= keep -- anti-conceal removes conceal=true marks on the cursor row
        -- hide the raw text
        marks[#marks + 1] = { conceal = hide, start_row = r, start_col = 0, opts = { end_row = r, end_col = #raw, conceal = "" } }
        -- rendered lines onto the raw row's wrap rows
        local R = #starts
        for i = 1, math.max(#lines, R) do
          local line = lines[i] or L.empty
          if i <= R then
            marks[#marks + 1] = { conceal = hide, start_row = r, start_col = starts[i], opts = { virt_text = line, virt_text_pos = "overlay" } }
          end
        end
        local extra = {}
        for i = R + 1, #lines do
          extra[#extra + 1] = lines[i]
        end
        if idx == #ordered then
          extra[#extra + 1] = L.bottom
        end
        if #extra > 0 then
          marks[#marks + 1] = { conceal = hide, start_row = r, start_col = 0, opts = { virt_lines = extra } }
        end
        if idx == 1 then
          marks[#marks + 1] = { conceal = hide, start_row = r, start_col = 0, opts = { virt_lines = { L.top }, virt_lines_above = true } }
        end
      end
  return marks
end

---render-markdown custom handler for the `markdown` language.
---@param ctx { buf: integer, root: TSNode, last: boolean }
---@return table[]
function M.parse_markdown(ctx)
  local marks = {}
  local win = window_for(ctx.buf)
  if not win then
    return marks
  end
  local W = text_width(win)
  local linebreak = vim.wo[win].linebreak
  local bufcache = cache[ctx.buf]
  if not bufcache or bufcache.W ~= W or bufcache.linebreak ~= linebreak then
    bufcache = { W = W, linebreak = linebreak, tables = {} }
    cache[ctx.buf] = bufcache
  end
  -- locked: nvim must not un-conceal the cursor line in normal mode; insert stays revealed
  local want = M.locked and "nvc" or ""
  if vim.wo[win].concealcursor ~= want then
    vim.wo[win].concealcursor = want
  end
  local mode = vim.api.nvim_get_mode().mode
  local reveal = mode:match("^[iRvV\22sS]") ~= nil -- typing or selecting: show the raw row
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(win))
  crow = crow - 1
  local seen = {}
  ts_query = ts_query or vim.treesitter.query.parse("markdown", "(pipe_table) @table")
  for _, node in ts_query:iter_captures(ctx.root, ctx.buf) do
    local sr, _, er, ec = node:range()
    if ec == 0 then
      er = er - 1
    end
    local slice = vim.api.nvim_buf_get_lines(ctx.buf, sr, er + 1, false)
    -- trailing non-table lines can sneak into the node range; trim them
    while #slice > 0 and not is_row(slice[#slice]) do
      slice[#slice] = nil
    end
    local key = sr .. "\0" .. table.concat(slice, "\n")
    -- the table under the cursor renders differently when locked: highlighted cell, marks
    -- kept on the cursor row (unless typing). Everything else is cursor-independent.
    local cursor, keep
    if M.locked and not reveal and crow >= sr and crow <= sr + #slice - 1 then
      local cells, spans = M.split_row(slice[crow - sr + 1])
      local cell = 1
      if cells then
        for i, sp in ipairs(spans) do
          local nxt = spans[i + 1]
          if ccol < (nxt and nxt[1] - 1 or math.huge) then
            cell = i
            break
          end
          cell = i
        end
      end
      cursor, keep = { row = crow, cell = cell }, crow
      key = key .. ("\0L%d:%d"):format(crow, cell)
    end
    seen[key] = true
    local hit = bufcache.tables[key]
    if not hit then
      local tbl = M.table_from_lines(slice, sr)
      hit = (tbl and tbl.ncols > 0) and table_marks(tbl, W, linebreak, cursor, keep) or {}
      bufcache.tables[key] = hit
    end
    vim.list_extend(marks, hit)
  end
  for key in pairs(bufcache.tables) do
    if not seen[key] then
      bufcache.tables[key] = nil
    end
  end
  return marks
end

---render-markdown handler for `markdown_inline`: the builtin marks, minus any that
---fall on a table row (those rows are drawn by parse_markdown).
function M.parse_inline(ctx)
  local builtin = require("render-markdown.handler.markdown_inline").parse(ctx)
  local ok, parser = pcall(vim.treesitter.get_parser, ctx.buf, "markdown")
  if not ok or not parser then
    return builtin
  end
  local rows = {}
  ts_query = ts_query or vim.treesitter.query.parse("markdown", "(pipe_table) @table")
  for _, tree in ipairs(parser:trees()) do
    for _, node in ts_query:iter_captures(tree:root(), ctx.buf) do
      local sr, _, er = node:range()
      for r = sr, er do
        rows[r] = true
      end
    end
  end
  local out = {}
  for _, m in ipairs(builtin) do
    if not rows[m.start_row] then
      out[#out + 1] = m
    end
  end
  return out
end

-- ---------------------------------------------------------------- editing commands

local function cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  return pos[1] - 1, pos[2]
end

---Index of the cell under the cursor on `line`, and the spans.
local function cell_index(line, col)
  local cells, spans = M.split_row(line)
  if not cells then
    return nil
  end
  for i, sp in ipairs(spans) do
    local nxt = spans[i + 1]
    if col < (nxt and nxt[1] - 1 or #line + 1) then
      return i, cells, spans
    end
  end
  return #cells, cells, spans
end

local function goto_cell(row, i)
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
  local cells, spans = M.split_row(line)
  if not cells then
    return false
  end
  i = math.max(1, math.min(i, #cells))
  vim.api.nvim_win_set_cursor(0, { row + 1, spans[i][1] })
  return true
end

function M.next_cell()
  local row, col = cursor()
  local tbl = M.table_at(0, row)
  if not tbl then
    return false
  end
  local i, cells = cell_index(tbl.lines[row + 1], col)
  if i < #cells then
    return goto_cell(row, i + 1)
  end
  -- last cell: first cell of the next body row
  local nxt = row == tbl.header and tbl.rows[1] or (row < tbl.last and row + 1 or nil)
  if nxt == tbl.delim then
    nxt = tbl.rows[1]
  end
  return nxt and goto_cell(nxt, 1) or false
end

function M.prev_cell()
  local row, col = cursor()
  local tbl = M.table_at(0, row)
  if not tbl then
    return false
  end
  local i = cell_index(tbl.lines[row + 1], col)
  if i > 1 then
    return goto_cell(row, i - 1)
  end
  local prv = row > tbl.header and row - 1 or nil
  if prv == tbl.delim then
    prv = tbl.header
  end
  if not prv then
    return false
  end
  local cells = M.split_row(tbl.lines[prv + 1])
  return goto_cell(prv, #cells)
end

local function move_row(delta)
  local row, col = cursor()
  local tbl = M.table_at(0, row)
  if not tbl then
    return false
  end
  local i = cell_index(tbl.lines[row + 1], col) or 1
  local target = row + delta
  if target == tbl.delim then
    target = target + delta
  end
  if target < tbl.first or target > tbl.last then
    return false
  end
  return goto_cell(target, i)
end

function M.next_row()
  return move_row(1)
end

function M.prev_row()
  return move_row(-1)
end

---Open the cell under the cursor in a float. :q saves and exits, :q! discards, :w saves in place.
function M.edit_cell()
  local row, col = cursor()
  local tbl = M.table_at(0, row)
  if not tbl or row == tbl.delim then
    return vim.notify("not on a table cell", vim.log.levels.INFO)
  end
  local src = vim.api.nvim_get_current_buf()
  local line = tbl.lines[row + 1]
  local i, cells, spans = cell_index(line, col)
  local text = cells[i]:gsub("\\|", "|")
  local header = M.split_row(tbl.lines[tbl.header + 1]) or {}
  local id = (cells[1] or ""):match("%[([^%]]+)%]") or cells[1] or ""
  local title = (" %s · %s "):format(id, header[i] or ("col " .. i))

  local cols = vim.o.columns
  local width = math.min(90, math.max(40, cols - 10))
  local wrapped = M.wrap_chunks({ { text, "Normal" } }, width - 2)
  local height = math.max(3, math.min(#wrapped + 2, vim.o.lines - 8))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "cell://" .. id .. "/" .. (header[i] or i))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((cols - width) / 2),
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    footer = " :q save and exit · :q! discard ",
    footer_pos = "right",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 0

  local _, _, inner = M.split_row(line)
  local function save()
    if vim.api.nvim_get_mode().mode:match("^i") then
      vim.cmd.stopinsert() -- so the source window is not left in insert mode after the float closes
    end
    local new = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), " ")
    new = vim.trim(new):gsub("|", "\\|")
    local cur = vim.api.nvim_buf_get_lines(src, row, row + 1, false)[1]
    if cur ~= line then
      return vim.notify("the row changed while the cell was open; not saved", vim.log.levels.ERROR)
    end
    -- replace everything between the pipes so the raw cell is always `| text |`
    vim.api.nvim_buf_set_text(src, row, inner[i][1], row, inner[i][2], { " " .. new .. " " })
    vim.bo[buf].modified = false
    vim.api.nvim_win_close(win, true)
  end
  -- :q saves and exits, :q! discards, :w saves in place. :q is a builtin, so a buffer-local
  -- command-line abbreviation rewrites a bare `q` to the save command; v:char is the key that
  -- triggered the expansion, so `q!` is left alone. Esc is plain Esc (leave insert, float
  -- stays open). Enter also saves and exits, since a cell is one line and a newline has no
  -- meaning here; o/O are no-ops for the same reason.
  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = save })
  vim.api.nvim_buf_create_user_command(buf, "WrappedTableCellSave", save, {})
  vim.cmd([[cnoreabbrev <buffer> <expr> q (getcmdtype() == ':' && getcmdline() == 'q' && v:char !=# '!') ? 'WrappedTableCellSave' : 'q']])
  vim.cmd([[cnoreabbrev <buffer> <expr> wq (getcmdtype() == ':' && getcmdline() == 'wq') ? 'WrappedTableCellSave' : 'wq']])
  vim.cmd([[cnoreabbrev <buffer> <expr> x (getcmdtype() == ':' && getcmdline() == 'x') ? 'WrappedTableCellSave' : 'x']])
  vim.keymap.set({ "n", "i" }, "<CR>", save, { buffer = buf, desc = "save cell and exit" })
  vim.keymap.set("n", "o", "<Nop>", { buffer = buf })
  vim.keymap.set("n", "O", "<Nop>", { buffer = buf })
end

local function replace_table_lines(tbl, new_lines)
  vim.api.nvim_buf_set_lines(0, tbl.first, tbl.last + 1, false, new_lines)
end

function M.add_row()
  local row = cursor()
  local tbl = M.table_at(0, row)
  if not tbl then
    return false
  end
  local at = (row <= tbl.delim) and tbl.delim or row
  vim.api.nvim_buf_set_lines(0, at + 1, at + 1, false, { "|" .. string.rep("  |", tbl.ncols) })
  goto_cell(at + 1, 1)
end

function M.delete_row()
  local row = cursor()
  local tbl = M.table_at(0, row)
  if not tbl or row <= tbl.delim then
    return vim.notify("only body rows can be deleted", vim.log.levels.INFO)
  end
  vim.api.nvim_buf_set_lines(0, row, row + 1, false, {})
end

local function map_columns(tbl, fn)
  local out = {}
  for r = tbl.first, tbl.last do
    local line = tbl.lines[r + 1]
    local cells = M.split_row(line) or {}
    local new = fn(cells, r)
    out[#out + 1] = "| " .. table.concat(new, " | ") .. " |"
  end
  replace_table_lines(tbl, out)
end

function M.add_column()
  local row, col = cursor()
  local tbl = M.table_at(0, row)
  if not tbl then
    return false
  end
  local i = cell_index(tbl.lines[row + 1], col) or tbl.ncols
  map_columns(tbl, function(cells, r)
    table.insert(cells, i + 1, r == tbl.delim and "---" or (r == tbl.header and "Col" or ""))
    return cells
  end)
  goto_cell(row, i + 1)
end

function M.delete_column()
  local row, col = cursor()
  local tbl = M.table_at(0, row)
  if not tbl or tbl.ncols < 2 then
    return false
  end
  local i = cell_index(tbl.lines[row + 1], col) or tbl.ncols
  map_columns(tbl, function(cells)
    table.remove(cells, i)
    return cells
  end)
  goto_cell(row, math.min(i, tbl.ncols - 1))
end

---Realign the raw table so every column is padded to its widest cell.
function M.format()
  local row = cursor()
  local tbl = M.table_at(0, row)
  if not tbl then
    return false
  end
  local widths = {}
  for r = tbl.first, tbl.last do
    if r ~= tbl.delim then
      for i, c in ipairs(M.split_row(tbl.lines[r + 1]) or {}) do
        widths[i] = math.max(widths[i] or 3, strwidth(c))
      end
    end
  end
  map_columns(tbl, function(cells, r)
    local out = {}
    for i = 1, tbl.ncols do
      local c = cells[i] or ""
      if r == tbl.delim then
        out[i] = string.rep("-", widths[i] or 3)
      else
        out[i] = c .. string.rep(" ", (widths[i] or 3) - strwidth(c))
      end
    end
    return out
  end)
end

local function plain(motion)
  vim.cmd.normal({ vim.v.count1 .. motion, bang = true })
end

---Arrow-key helper: run `fn` when on a table row (falling back to the plain motion when
---it has nowhere to go, e.g. Down on the last row), else the plain motion.
function M.on_table_or(fn, motion)
  return function()
    local row = cursor()
    if not (M.table_at(0, row) and fn()) then
      plain(motion)
    end
  end
end

local HJKL = { h = "prev_cell", l = "next_cell", j = "next_row", k = "prev_row" }

---hjkl: move by cell/row while the lock is on and the cursor is on a table; otherwise the
---normal motion, counts preserved.
function M.hjkl(key)
  return function()
    if M.locked and vim.v.count == 0 then
      local row = cursor()
      if M.table_at(0, row) and M[HJKL[key]]() then
        return
      end
    end
    plain(key)
  end
end

local function rerender(buf)
  pcall(function()
    require("render-markdown.api").render({ buf = buf, event = "WrappedTables" })
  end)
end

---i / a on a locked table row: the cursor is hidden there, so insert at the start (i) or
---end (a) of the highlighted cell's text; the row reveals itself in insert mode as usual.
---Elsewhere they are the plain commands.
function M.insert(key)
  return function()
    if M.locked and vim.v.count == 0 then
      local row, col = cursor()
      local tbl = M.table_at(0, row)
      if tbl and row ~= tbl.delim then
        local i, _, spans = cell_index(tbl.lines[row + 1], col)
        if i then
          vim.api.nvim_win_set_cursor(0, { row + 1, key == "a" and spans[i][2] or spans[i][1] })
          vim.cmd.startinsert()
          return
        end
      end
    end
    vim.api.nvim_feedkeys(vim.v.count1 .. key, "n", false)
  end
end

-- cursor hiding: guicursor is global, so swap it while in normal mode on a locked table row
-- and put the user's value back the moment that stops being true
local saved_guicursor ---@type string?

local function hide_cursor(hide)
  if hide and not saved_guicursor then
    saved_guicursor = vim.o.guicursor
    vim.o.guicursor = "a:WrappedTableHiddenCursor/WrappedTableHiddenCursor"
  elseif not hide and saved_guicursor then
    vim.o.guicursor = saved_guicursor
    saved_guicursor = nil
  end
end

---Enter on a table row opens the cell float (and Enter inside it saves and exits); off a
---table, Enter is the plain motion it always was.
function M.enter()
  local row = cursor()
  local tbl = M.table_at(0, row)
  if tbl and row ~= tbl.delim then
    M.edit_cell()
  else
    plain("\r")
  end
end

---<leader>tt: flip between locked (tables always rendered) and hover (cursor row raw).
function M.toggle_lock()
  M.locked = not M.locked
  if not M.locked then
    hide_cursor(false)
  end
  last = {}
  rerender(vim.api.nvim_get_current_buf())
  vim.notify(M.locked and "tables: locked (rendered under the cursor, hjkl by cell)" or "tables: hover (cursor row raw)", vim.log.levels.INFO)
end

-- render-markdown only re-runs handlers when the buffer changes; locked tables also depend
-- on which cell the cursor is in and on the mode (insert reveals the row), so ask for a
-- re-render when either changes while the cursor is on or was on a table. The per-table
-- cache keeps this at about a millisecond.
local last = {} ---@type table<integer, string>

local function cursor_state(buf)
  local row, col = cursor()
  local tbl = M.table_at(buf, row)
  if not tbl then
    return "off"
  end
  local i = cell_index(tbl.lines[row + 1], col) or 0
  return ("%d:%d:%s"):format(row, i, vim.api.nvim_get_mode().mode:sub(1, 1))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("WrappedTables", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
    group = group,
    pattern = "*",
    callback = function(args)
      if not M.locked or vim.bo[args.buf].filetype ~= "markdown" then
        return
      end
      if vim.api.nvim_get_current_buf() ~= args.buf then
        return
      end
      local state = cursor_state(args.buf)
      local prev = last[args.buf]
      last[args.buf] = state
      -- on a table row in normal mode: only the highlighted cell shows the position
      hide_cursor(state ~= "off" and state:sub(-1) == "n")
      if state ~= prev and (state ~= "off" or prev ~= "off") then
        rerender(args.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "FocusLost", "VimLeavePre" }, {
    group = group,
    pattern = "*",
    callback = function()
      hide_cursor(false)
    end,
  })
end

return M
