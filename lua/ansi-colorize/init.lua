local M = {}

local ns = vim.api.nvim_create_namespace("ansi-colorize")
local conceal_group = vim.api.nvim_create_augroup("ansi-colorize-conceal", { clear = false })
local groups = {}
-- `:colorscheme` runs `:hi clear`, which wipes our groups. Redefine them right
-- away, so text that is already highlighted keeps its colours.
local function define_link_group()
  vim.api.nvim_set_hl(0, "AnsiColorizeLink", { link = "Underlined", default = true })
end
define_link_group()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ansi-colorize-groups", { clear = true }),
  callback = function()
    for name, spec in pairs(groups) do
      vim.api.nvim_set_hl(0, name, spec)
    end
    define_link_group()
  end,
})
local config = {
  overseer = false,
  links = {
    -- Turn OSC 8 hyperlinks into `url` extmarks (open with gx / Ctrl-click).
    enabled = true,
    -- Buffer-local normal-mode key that opens a file:// link under the cursor
    -- in Neovim (jumping to :line[:col]); other keys fall back to their
    -- normal behaviour. nil = no mapping.
    open_file_keymap = nil,
  },
}

local LINK_GROUP = "AnsiColorizeLink"

local ansi16 = {
  "#000000",
  "#cd0000",
  "#00cd00",
  "#cdcd00",
  "#0000ee",
  "#cd00cd",
  "#00cdcd",
  "#e5e5e5",
  "#7f7f7f",
  "#ff0000",
  "#00ff00",
  "#ffff00",
  "#5c5cff",
  "#ff00ff",
  "#00ffff",
  "#ffffff",
}

local function color16(i)
  local name = "terminal_color_" .. i
  return vim.g[name] or ansi16[i + 1]
end

local function color256(i)
  if i < 16 then
    return color16(i)
  end
  if i >= 16 and i <= 231 then
    i = i - 16
    local r = math.floor(i / 36)
    local g = math.floor((i % 36) / 6)
    local b = i % 6
    local function level(n)
      return n == 0 and 0 or 55 + n * 40
    end
    return string.format("#%02x%02x%02x", level(r), level(g), level(b))
  end
  if i >= 232 and i <= 255 then
    local v = 8 + (i - 232) * 10
    return string.format("#%02x%02x%02x", v, v, v)
  end
end

local function parse_params(raw)
  if raw == "" then
    return { 0 }
  end
  local params = {}
  params._colon = {}
  for part, separator in (raw .. ";"):gmatch("(.-)([;:])") do
    params[#params + 1] = tonumber(part) or 0
    params._colon[#params] = separator == ":"
  end
  return #params == 0 and { 0 } or params
end

local function copy_state(state)
  return {
    fg = state.fg,
    bg = state.bg,
    sp = state.sp,
    ctermfg = state.ctermfg,
    ctermbg = state.ctermbg,
    bold = state.bold,
    dim = state.dim,
    italic = state.italic,
    underline = state.underline,
    strikethrough = state.strikethrough,
    reverse = state.reverse,
    url = state.url,
  }
end

local function apply_sgr(state, params)
  local i = 1
  while i <= #params do
    local p = params[i]
    if p == 0 then
      state.fg, state.bg, state.sp, state.ctermfg, state.ctermbg = nil, nil, nil, nil, nil
      state.bold, state.italic, state.underline, state.strikethrough, state.reverse = nil, nil, nil, nil, nil
      state.dim = nil
    elseif p == 1 then
      state.bold = true
    elseif p == 2 then
      state.dim = true
    elseif p == 3 then
      state.italic = true
    elseif p == 4 then
      if params._colon and params._colon[i] then
        state.underline = ({ [1] = true, [2] = "double", [3] = "curl", [4] = "dotted", [5] = "dashed" })[params[i + 1]]
        i = i + 1
      else
        state.underline = true
      end
    elseif p == 7 then
      state.reverse = true
    elseif p == 9 then
      state.strikethrough = true
    elseif p == 21 then
      state.underline = "double"
    elseif p == 22 then
      state.bold, state.dim = nil, nil
    elseif p == 23 then
      state.italic = nil
    elseif p == 24 then
      state.underline = nil
    elseif p == 27 then
      state.reverse = nil
    elseif p == 29 then
      state.strikethrough = nil
    elseif p == 39 then
      state.fg, state.ctermfg = nil, nil
    elseif p == 49 then
      state.bg, state.ctermbg = nil, nil
    elseif p == 59 then
      state.sp = nil
    elseif p >= 30 and p <= 37 then
      state.fg, state.ctermfg = color16(p - 30), p - 30
    elseif p >= 40 and p <= 47 then
      state.bg, state.ctermbg = color16(p - 40), p - 40
    elseif p >= 90 and p <= 97 then
      state.fg, state.ctermfg = color16(p - 90 + 8), p - 90 + 8
    elseif p >= 100 and p <= 107 then
      state.bg, state.ctermbg = color16(p - 100 + 8), p - 100 + 8
    elseif (p == 38 or p == 48 or p == 58) and params[i + 1] == 2 and params._colon and params._colon[i]
        and params._colon[i + 1] and params._colon[i + 2] and params._colon[i + 3] and params._colon[i + 4] then
      -- ITU T.416 form with a colour-space id: 38:2:<cs>:r:g:b (the id is often empty).
      local color = string.format("#%02x%02x%02x", params[i + 3] % 256, params[i + 4] % 256, params[i + 5] % 256)
      if p == 38 then
        state.fg, state.ctermfg = color, nil
      elseif p == 48 then
        state.bg, state.ctermbg = color, nil
      else
        state.sp = color
      end
      i = i + 5
    elseif (p == 38 or p == 48 or p == 58) and params[i + 1] == 5 then
      local index = params[i + 2]
      local color = color256(index or -1)
      if index and (index < 0 or index > 255) then
        index = nil
      end
      if p == 38 then
        state.fg, state.ctermfg = color, color and index
      elseif p == 48 then
        state.bg, state.ctermbg = color, color and index
      else
        state.sp = color
      end
      i = i + 2
    elseif (p == 38 or p == 48 or p == 58) and params[i + 1] == 2 then
      local r, g, b = params[i + 2], params[i + 3], params[i + 4]
      if r and g and b then
        local color = string.format("#%02x%02x%02x", r % 256, g % 256, b % 256)
        if p == 38 then
          state.fg, state.ctermfg = color, nil
        elseif p == 48 then
          state.bg, state.ctermbg = color, nil
        else
          state.sp = color
        end
      end
      i = i + 4
    end
    i = i + 1
  end
end

local function state_key(state)
  return table.concat({
    state.fg or "",
    state.bg or "",
    state.sp or "",
    state.ctermfg or "",
    state.ctermbg or "",
    state.bold and "b" or "",
    state.dim and "d" or "",
    state.italic and "i" or "",
    state.underline == true and "u" or state.underline or "",
    state.strikethrough and "s" or "",
    state.reverse and "r" or "",
  }, "_")
end

-- dim (SGR 2): the colour at 60%, or the Comment colour without one
local function dimmed(hex)
  local r, g, b = (hex or ""):match("^#(%x%x)(%x%x)(%x%x)$")
  if not r then
    return vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg
  end
  local function d(x)
    return math.floor(tonumber(x, 16) * 0.6)
  end
  return string.format("#%02x%02x%02x", d(r), d(g), d(b))
end

local function hl_group(state)
  if not (state.fg or state.bg or state.sp or state.bold or state.dim or state.italic or state.underline or state.strikethrough or state.reverse) then
    return nil
  end
  local key = state_key(state):gsub("[^%w_]", "")
  local name = "AnsiColorize_" .. key
  if not groups[name] then
    local spec = {
      fg = state.dim and dimmed(state.fg) or state.fg,
      bg = state.bg,
      ctermfg = state.ctermfg,
      ctermbg = state.ctermbg,
      sp = state.sp,
      bold = state.bold,
      italic = state.italic,
      underline = state.underline == true,
      undercurl = state.underline == "curl",
      underdouble = state.underline == "double",
      underdotted = state.underline == "dotted",
      underdashed = state.underline == "dashed",
      strikethrough = state.strikethrough,
      reverse = state.reverse,
    }
    vim.api.nvim_set_hl(0, name, spec)
    groups[name] = spec
  end
  return name
end

-- `state` carries SGR attributes from previous lines, like a terminal does.
local function parse_line(line, state)
  local spans, escapes = {}, {}
  local clean = {}
  local pos, clean_col = 1, 0

  while true do
    -- Next SGR sequence or OSC 8 hyperlink (open or close), whichever is first.
    local s, e, params = line:find("\27%[([%d;:]*)m", pos)
    local os, oe, uri = line:find("\27%]8;[^;\7\27]*;([^\7\27]*)\7", pos)
    if not os then
      os, oe, uri = line:find("\27%]8;[^;\7\27]*;([^\7\27]*)\27\\", pos)
    end
    local link = false
    if os and (not s or os < s) then
      s, e, link = os, oe, true
    end
    if not s then
      local text = line:sub(pos)
      if text ~= "" then
        spans[#spans + 1] = {
          source_start = pos - 1,
          source_end = #line,
          clean_start = clean_col,
          clean_end = clean_col + #text,
          state = copy_state(state),
        }
        clean[#clean + 1] = text
      end
      break
    end

    local text = line:sub(pos, s - 1)
    if text ~= "" then
      spans[#spans + 1] = {
        source_start = pos - 1,
        source_end = s - 1,
        clean_start = clean_col,
        clean_end = clean_col + #text,
        state = copy_state(state),
      }
      clean[#clean + 1] = text
      clean_col = clean_col + #text
    end

    escapes[#escapes + 1] = { start_col = s - 1, end_col = e }
    if link then
      state.url = uri ~= "" and uri or nil
    else
      apply_sgr(state, parse_params(params))
    end
    pos = e + 1
  end

  return table.concat(clean), spans, escapes
end

local function set_conceal_options(win)
  win = win == 0 and vim.api.nvim_get_current_win() or win
  if vim.w[win].ansi_colorize_saved_conceal == nil then
    vim.w[win].ansi_colorize_saved_conceal = {
      vim.api.nvim_get_option_value("conceallevel", { win = win }),
      vim.api.nvim_get_option_value("concealcursor", { win = win }),
    }
  end
  vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
  vim.api.nvim_set_option_value("concealcursor", "nvic", { win = win })
end

local function enable_conceal(bufnr)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    set_conceal_options(win)
  end
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = conceal_group,
    buffer = bufnr,
    callback = function()
      set_conceal_options(0)
    end,
  })
end

local function valid_buf(bufnr)
  bufnr = bufnr and tonumber(bufnr) or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    error("invalid buffer: " .. tostring(bufnr))
  end
  return bufnr
end

---@class AnsiColorizeDecoder
---@field row integer row of the next text, from 0
---@field col integer byte column of the next text
local Decoder = {}
Decoder.__index = Decoder

---A decoder for one stream of text, fed in chunks of any size: SGR state
---carries across chunks and lines, and an escape sequence cut off at the end
---of a chunk is completed by the next one. Rows and columns count from where
---the stream starts (row 0, column 0).
---@return AnsiColorizeDecoder
function M.decoder()
  return setmetatable({ row = 0, col = 0, state = {}, carry = "" }, Decoder)
end

---Decode a chunk: its text without escape sequences (`\r` dropped), and the
---highlight spans `{row, start_col, end_col, hl_group}` of that text. OSC 8
---hyperlinks add spans `{row, start_col, end_col, "AnsiColorizeLink", url}`.
---@param chunk string
---@return string text, {[1]: integer, [2]: integer, [3]: integer, [4]: string}[] spans
function Decoder:feed(chunk)
  local s = self.carry .. chunk
  self.carry = ""
  local out, spans = {}, {}
  local function close()
    if self.open and self.col > self.open.col then
      spans[#spans + 1] = { self.row, self.open.col, self.col, self.open.group }
    end
    self.open = nil
  end
  local function open()
    local group = hl_group(self.state)
    if group then
      self.open = { col = self.col, group = group }
    end
  end
  local function close_link()
    if self.link and self.col > self.link.col then
      spans[#spans + 1] = { self.row, self.link.col, self.col, LINK_GROUP, self.link.url }
    end
  end
  local function open_link(url)
    self.link = url and { col = self.col, url = url } or nil
  end
  local i, n = 1, #s
  while i <= n do
    local b = s:byte(i)
    if b == 27 then
      local kind = s:sub(i + 1, i + 1)
      if kind == "" then
        self.carry = s:sub(i)
        break
      elseif kind == "[" then
        -- CSI: parameter and intermediate bytes, then a final byte
        local j = i + 2
        while j <= n and s:byte(j) >= 0x20 and s:byte(j) <= 0x3f do
          j = j + 1
        end
        if j > n then
          self.carry = s:sub(i)
          break
        end
        if s:sub(j, j) == "m" then
          close()
          apply_sgr(self.state, parse_params(s:sub(i + 2, j - 1)))
          open()
        end
        i = j + 1
      elseif kind == "]" then
        -- OSC (hyperlinks, titles): up to BEL or ST
        local bel = s:find("\7", i + 2, true)
        local st = s:find("\27\\", i + 2, true)
        local e = bel and (not st or bel < st) and bel or st
        if not e then
          self.carry = s:sub(i)
          break
        end
        local uri = s:sub(i, e - 1):match("^\27%]8;[^;]*;(.*)$")
        if uri and config.links.enabled then
          close_link()
          open_link(uri ~= "" and uri or nil)
        end
        i = e + (e == bel and 1 or 2)
      else
        i = i + 2
      end
    elseif b == 10 then
      close()
      close_link()
      out[#out + 1] = "\n"
      self.row = self.row + 1
      self.col = 0
      open()
      open_link(self.link and self.link.url)
      i = i + 1
    elseif b == 13 then
      i = i + 1
    else
      local j = s:find("[\27\n\r]", i) or n + 1
      local text = s:sub(i, j - 1)
      out[#out + 1] = text
      self.col = self.col + #text
      i = j
    end
  end
  -- the span open so far; the next chunk continues it
  if self.open and self.col > self.open.col then
    spans[#spans + 1] = { self.row, self.open.col, self.col, self.open.group }
    self.open.col = self.col
  end
  if self.link and self.col > self.link.col then
    spans[#spans + 1] = { self.row, self.link.col, self.col, LINK_GROUP, self.link.url }
    self.link.col = self.col
  end
  return table.concat(out), spans
end

---Decode a whole text: its lines without escape sequences and their spans.
---@param text string
---@return string[] lines, {[1]: integer, [2]: integer, [3]: integer, [4]: string}[] spans
function M.decode(text)
  local clean, spans = M.decoder():feed(text)
  return vim.split(clean, "\n", { plain = true }), spans
end

---Text without escape sequences (CSI, OSC and two-byte escapes).
---@param text string
---@return string
function M.strip_text(text)
  if not text:find("\27", 1, true) then
    return text
  end
  return (
    text
      :gsub("\27%[[0-?]*[ -/]*[@-~]", "")
      :gsub("\27%][^\7\27]*\7", "")
      :gsub("\27%][^\27]*\27\\", "")
      :gsub("\27.", "")
  )
end

---Highlight decoded spans in a buffer, `opts.row` lines down (default 0),
---in this plugin's namespace (`M.ns`), so `clear()` removes them. Link spans
---get a `url`, so gx (and Ctrl-click in a supporting terminal) opens them.
---@param bufnr integer?
---@param spans {[1]: integer, [2]: integer, [3]: integer, [4]: string}[]
---@param opts? {row?: integer}
function M.apply(bufnr, spans, opts)
  bufnr = valid_buf(bufnr)
  local row = opts and opts.row or 0
  local links = false
  for _, span in ipairs(spans) do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, span[1] + row, span[2], {
      end_row = span[1] + row,
      end_col = span[3],
      hl_group = span[4],
      url = span[5],
      priority = span[5] and 199 or 200,
    })
    links = links or span[5] ~= nil
  end
  if links then
    M.map_open_file(bufnr)
  end
end

M.ns = ns

function M.clear(bufnr)
  bufnr = valid_buf(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.api.nvim_clear_autocmds({ group = conceal_group, buffer = bufnr })
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    local saved = vim.w[win].ansi_colorize_saved_conceal
    if saved then
      vim.api.nvim_set_option_value("conceallevel", saved[1], { win = win })
      vim.api.nvim_set_option_value("concealcursor", saved[2], { win = win })
      vim.w[win].ansi_colorize_saved_conceal = nil
    end
  end
end

---The OSC 8 link target under the cursor (or at `row`/`col`, 0-based), and
---the link's extmark end column.
---@return string? url, integer? end_col
function M.link_at(bufnr, row, col)
  bufnr = valid_buf(bufnr)
  if not row then
    local cursor = vim.api.nvim_win_get_cursor(0)
    row, col = cursor[1] - 1, cursor[2]
  end
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { row, col }, { row, col }, {
    details = true,
    overlap = true,
  })
  for _, mark in ipairs(marks) do
    if mark[4].url then
      return mark[4].url, mark[4].end_col
    end
  end
end

---Open the file:// link under the cursor in Neovim. The line (and column) come
---from the URI fragment (`#L12`, `#12`, `#12:3`) or from `:12:3` right after
---the link text, as compilers print it. Returns false when there is no
---file:// link under the cursor.
---@return boolean opened
function M.open_link()
  local bufnr = vim.api.nvim_get_current_buf()
  local url, end_col = M.link_at(bufnr)
  if not url or not url:match("^file://") then
    return false
  end
  local path, fragment = url:match("^([^#]*)#?(.*)$")
  local lnum, col = fragment:match("^L?(%d+)[:,C]?(%d*)")
  if not lnum and end_col then
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local rest = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    -- In conceal mode the closing escape still sits between the text and ":12".
    lnum, col = M.strip_text(rest:sub(end_col + 1)):match("^:(%d+):?(%d*)")
  end
  local file = vim.uri_to_fname(path)
  -- Don't replace the content of a floating task window.
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    vim.cmd.wincmd("p")
  end
  vim.cmd.edit(vim.fn.fnameescape(file))
  if lnum then
    local line = math.min(tonumber(lnum), vim.api.nvim_buf_line_count(0))
    pcall(vim.api.nvim_win_set_cursor, 0, { line, math.max(0, (tonumber(col) or 1) - 1) })
  end
  return true
end

---Map `links.open_file_keymap` in `bufnr` (once): open a file:// link under the
---cursor in Neovim, otherwise run the key's normal behaviour.
function M.map_open_file(bufnr)
  local key = config.links.open_file_keymap
  if not key or vim.b[bufnr].ansi_colorize_link_key == key then
    return
  end
  vim.b[bufnr].ansi_colorize_link_key = key
  vim.keymap.set("n", key, function()
    if not M.open_link() then
      vim.api.nvim_feedkeys(vim.keycode(key), "n", false)
    end
  end, { buffer = bufnr, desc = "Open file:// link under cursor" })
end

function M.colorize(bufnr, opts)
  bufnr = valid_buf(bufnr)
  opts = opts or {}
  local strip = opts.strip == true
  if strip and vim.bo[bufnr].buftype == "terminal" then
    error("ansi-colorize: strip mode cannot edit terminal buffers; use conceal mode")
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local parsed = {}
  local state = {}
  local has_links = false

  for i, line in ipairs(lines) do
    local clean, spans, escapes = parse_line(line, state)
    parsed[i] = { clean = clean, spans = spans, escapes = escapes }
  end

  M.clear(bufnr)

  if strip then
    local clean_lines = {}
    for i, item in ipairs(parsed) do
      clean_lines[i] = item.clean
    end
    -- Task output buffers (e.g. Overseer's) are usually nomodifiable.
    local modifiable = vim.bo[bufnr].modifiable
    vim.bo[bufnr].modifiable = true
    local ok, err = pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, clean_lines)
    vim.bo[bufnr].modifiable = modifiable
    if not ok then error(err) end
  else
    enable_conceal(bufnr)
  end

  for line_nr, item in ipairs(parsed) do
    for _, escape in ipairs(item.escapes) do
      if not strip then
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr - 1, escape.start_col, {
          end_col = escape.end_col,
          conceal = "",
          priority = 200,
        })
      end
    end
    for _, span in ipairs(item.spans) do
      local start_col = strip and span.clean_start or span.source_start
      local end_col = strip and span.clean_end or span.source_end
      local group = hl_group(span.state)
      if group then
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr - 1, start_col, {
          end_col = end_col,
          hl_group = group,
          priority = 200,
        })
      end
      if span.state.url and config.links.enabled then
        has_links = true
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr - 1, start_col, {
          end_col = end_col,
          hl_group = LINK_GROUP,
          url = span.state.url,
          priority = 199,
        })
      end
    end
  end
  if has_links then
    M.map_open_file(bufnr)
  end
end

function M.strip(bufnr)
  M.colorize(bufnr, { strip = true })
end

function M.links_enabled()
  return config.links.enabled ~= false
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  if config.overseer then
    require("ansi-colorize.overseer").setup(config.overseer)
  end
end

return M
