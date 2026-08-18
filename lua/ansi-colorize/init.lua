local M = {}

local ns = vim.api.nvim_create_namespace("ansi-colorize")
local groups = {}
local config = {
  overseer = false,
}

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
    bold = state.bold,
    italic = state.italic,
    underline = state.underline,
    strikethrough = state.strikethrough,
    reverse = state.reverse,
  }
end

local function apply_sgr(state, params)
  local i = 1
  while i <= #params do
    local p = params[i]
    if p == 0 then
      state.fg, state.bg, state.sp = nil, nil, nil
      state.bold, state.italic, state.underline, state.strikethrough, state.reverse = nil, nil, nil, nil, nil
    elseif p == 1 then
      state.bold = true
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
      state.bold = nil
    elseif p == 23 then
      state.italic = nil
    elseif p == 24 then
      state.underline = nil
    elseif p == 27 then
      state.reverse = nil
    elseif p == 29 then
      state.strikethrough = nil
    elseif p == 39 then
      state.fg = nil
    elseif p == 49 then
      state.bg = nil
    elseif p == 59 then
      state.sp = nil
    elseif p >= 30 and p <= 37 then
      state.fg = color16(p - 30)
    elseif p >= 40 and p <= 47 then
      state.bg = color16(p - 40)
    elseif p >= 90 and p <= 97 then
      state.fg = color16(p - 90 + 8)
    elseif p >= 100 and p <= 107 then
      state.bg = color16(p - 100 + 8)
    elseif (p == 38 or p == 48 or p == 58) and params[i + 1] == 5 then
      local color = color256(params[i + 2] or -1)
      if p == 38 then
        state.fg = color
      elseif p == 48 then
        state.bg = color
      else
        state.sp = color
      end
      i = i + 2
    elseif (p == 38 or p == 48 or p == 58) and params[i + 1] == 2 then
      local r, g, b = params[i + 2], params[i + 3], params[i + 4]
      if r and g and b then
        local color = string.format("#%02x%02x%02x", r % 256, g % 256, b % 256)
        if p == 38 then
          state.fg = color
        elseif p == 48 then
          state.bg = color
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
    state.bold and "b" or "",
    state.italic and "i" or "",
    state.underline == true and "u" or state.underline or "",
    state.strikethrough and "s" or "",
    state.reverse and "r" or "",
  }, "_")
end

local function hl_group(state)
  if not (state.fg or state.bg or state.sp or state.bold or state.italic or state.underline or state.strikethrough or state.reverse) then
    return nil
  end
  local key = state_key(state):gsub("[^%w_]", "")
  local name = "AnsiColorize_" .. key
  if not groups[name] then
    vim.api.nvim_set_hl(0, name, {
      fg = state.fg,
      bg = state.bg,
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
    })
    groups[name] = true
  end
  return name
end

local function parse_line(line)
  local spans, escapes = {}, {}
  local clean, state = {}, {}
  local pos, clean_col = 1, 0

  while true do
    local s, e, params = line:find("\27%[([%d;:]*)m", pos)
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
    apply_sgr(state, parse_params(params))
    pos = e + 1
  end

  return table.concat(clean), spans, escapes
end

local function set_conceal_options(bufnr)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
    vim.api.nvim_set_option_value("concealcursor", "nvic", { win = win })
  end
end

local function valid_buf(bufnr)
  bufnr = bufnr and tonumber(bufnr) or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    error("invalid buffer: " .. tostring(bufnr))
  end
  return bufnr
end

function M.clear(bufnr)
  bufnr = valid_buf(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

function M.colorize(bufnr, opts)
  bufnr = valid_buf(bufnr)
  opts = opts or {}
  local strip = opts.strip == true
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local parsed = {}

  for i, line in ipairs(lines) do
    local clean, spans, escapes = parse_line(line)
    parsed[i] = { clean = clean, spans = spans, escapes = escapes }
  end

  M.clear(bufnr)

  if strip then
    local clean_lines = {}
    for i, item in ipairs(parsed) do
      clean_lines[i] = item.clean
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, clean_lines)
  else
    set_conceal_options(bufnr)
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
      local group = hl_group(span.state)
      if group then
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr - 1, strip and span.clean_start or span.source_start, {
          end_col = strip and span.clean_end or span.source_end,
          hl_group = group,
          priority = 200,
        })
      end
    end
  end
end

function M.strip(bufnr)
  M.colorize(bufnr, { strip = true })
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  if config.overseer then
    require("ansi-colorize.overseer").setup(config.overseer)
  end
end

return M
