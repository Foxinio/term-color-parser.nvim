vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/ansi-colorize.lua")

local ansi = require("ansi-colorize")
local ns = vim.api.nvim_create_namespace("ansi-colorize")

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", label, expected, actual))
  end
end

local function new_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function marks(bufnr)
  return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
end

local function has_detail(bufnr, key, value)
  for _, mark in ipairs(marks(bufnr)) do
    if mark[4][key] == value then
      return true
    end
  end
  return false
end

local function has_highlight(bufnr, key, value)
  for _, mark in ipairs(marks(bufnr)) do
    local group = mark[4].hl_group
    if group and vim.api.nvim_get_hl(0, { name = group })[key] == value then
      return true
    end
  end
  return false
end

assert_eq(require("term-color-parser"), ansi, "lazy.nvim main module alias")

local bufnr = new_buf({ "\27[31mred\27[0m plain \27[38;5;45mblue\27[0m" })
ansi.colorize(bufnr)
assert_eq(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1], "\27[31mred\27[0m plain \27[38;5;45mblue\27[0m", "conceal keeps text")

assert(#marks(bufnr) >= 4, "conceal mode should create extmarks")
assert(has_detail(bufnr, "conceal", ""), "conceal mode should hide escape sequences")
assert_eq(vim.api.nvim_get_option_value("conceallevel", { win = 0 }), 2, "conceallevel is set")
assert_eq(vim.api.nvim_get_option_value("concealcursor", { win = 0 }), "nvic", "concealcursor is set")

local stripped = new_buf({ "x\27[1;4;38;2;1;2;3mstyled\27[22;24;39my" })
ansi.strip(stripped)
assert_eq(vim.api.nvim_buf_get_lines(stripped, 0, -1, false)[1], "xstyledy", "strip removes escapes")

local empty_param = new_buf({ "\27[;31mred\27[0m" })
ansi.strip(empty_param)
assert_eq(vim.api.nvim_buf_get_lines(empty_param, 0, -1, false)[1], "red", "empty sgr params are accepted")

local visual_styles = new_buf({ "\27[9mstrike\27[29m \27[4:3;58;2;1;2;3mcurly\27[0m" })
ansi.colorize(visual_styles)
assert(has_highlight(visual_styles, "strikethrough", true), "strikethrough is highlighted")
assert(has_highlight(visual_styles, "undercurl", true), "underline styles are highlighted")
assert(has_highlight(visual_styles, "sp", 0x010203), "underline colors are highlighted")

ansi.clear(stripped)
assert_eq(#marks(stripped), 0, "clear removes extmarks")

local malformed = new_buf({ "before \27[not-sgr after \27[999mstill here" })
ansi.colorize(malformed)
assert_eq(vim.api.nvim_buf_get_lines(malformed, 0, -1, false)[1], "before \27[not-sgr after \27[999mstill here", "malformed input is stable")

local command_current = new_buf({ "\27[32mgreen\27[0m" })
vim.cmd("AnsiColorize")
assert_eq(vim.api.nvim_buf_get_lines(command_current, 0, -1, false)[1], "\27[32mgreen\27[0m", "command defaults to current buffer")
assert(has_detail(command_current, "conceal", ""), "command applies conceal mode")

local command_other = new_buf({ "stay raw" })
local target = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(target, 0, -1, false, { "\27[33myellow\27[0m" })
vim.cmd("AnsiColorize " .. target)
assert_eq(vim.api.nvim_buf_get_lines(command_other, 0, -1, false)[1], "stay raw", "buffer argument does not touch current buffer")
assert(has_detail(target, "conceal", ""), "buffer argument colorizes target buffer")

local command_bang = new_buf({ "\27[34mblue\27[0m" })
vim.cmd("AnsiColorize!")
assert_eq(vim.api.nvim_buf_get_lines(command_bang, 0, -1, false)[1], "blue", "bang command strips current buffer")

local preserve_calls = 0
package.loaded["ansi-colorize.overseer"] = {
  preserve_overseer_ansi = function()
    preserve_calls = preserve_calls + 1
  end,
}
local overseer_component = dofile("lua/overseer/component/ansi_colorize.lua")
local overseer_buf = new_buf({ "\27[35mmagenta\27[0m" })
local fake_task = { get_bufnr = function() return overseer_buf end }
overseer_component.constructor({ mode = "conceal", on = "output" }):on_output(fake_task)
assert_eq(preserve_calls, 1, "overseer component enables ansi preservation")
overseer_component.constructor({ preserve_ansi = false })
assert_eq(preserve_calls, 1, "overseer component can disable ansi preservation")
package.loaded["ansi-colorize.overseer"] = nil
vim.wait(1000, function()
  return has_detail(overseer_buf, "conceal", "")
end)
assert(has_detail(overseer_buf, "conceal", ""), "overseer component colorizes output")

local overseer_strip = new_buf({ "\27[36mcyan\27[0m" })
local fake_strip_task = { get_bufnr = function() return overseer_strip end }
overseer_component.constructor({ mode = "strip", on = "complete" }):on_complete(fake_strip_task)
vim.wait(1000, function()
  return vim.api.nvim_buf_get_lines(overseer_strip, 0, -1, false)[1] == "cyan"
end)
assert_eq(vim.api.nvim_buf_get_lines(overseer_strip, 0, -1, false)[1], "cyan", "overseer component supports strip mode")

local hooks = {}
local fake_overseer_util = {}
fake_overseer_util.clean_job_line = function(str)
  return str:gsub("\27%[[%d;]*m", ""):gsub("\r$", "")
end
fake_overseer_util.get_stdout_line_iter = function()
  return function(data)
    return vim.tbl_map(fake_overseer_util.clean_job_line, data)
  end
end
package.loaded["overseer.util"] = fake_overseer_util
local fake_quickfix = {
  constructor = function()
    return {
      on_pre_result = function(_, task)
        return vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, true)[1]
      end,
    }
  end,
}
package.loaded["overseer.component"] = {
  get = function()
    return fake_quickfix
  end,
}
package.loaded.overseer = {
  add_template_hook = function(filter, callback)
    hooks[#hooks + 1] = { filter = filter, callback = callback }
  end,
}

local ok = require("ansi-colorize.overseer").setup({ mode = "strip", filter = { module = "^make$" } })
assert(ok, "overseer setup reports success when overseer is available")
assert_eq(package.loaded["overseer.util"].clean_job_line("\27[31mred\27[0m\r"), "\27[31mred\27[0m", "overseer setup preserves ansi")
assert_eq(package.loaded["overseer.util"].get_stdout_line_iter()({ "\27[31mfile.lua:1: error\27[0m\r" })[1], "file.lua:1: error", "overseer parsers receive clean lines")
local quickfix_buf = new_buf({ "\27[4:3mfile.lua:1: error\27[0m" })
local quickfix_task = { get_bufnr = function() return quickfix_buf end }
local quickfix = package.loaded["overseer.component"].get()
assert_eq(quickfix.constructor({ tail = false }).on_pre_result({}, quickfix_task), "file.lua:1: error", "completed quickfix receives clean lines")
assert_eq(vim.api.nvim_buf_get_lines(quickfix_buf, 0, -1, true)[1], "\27[4:3mfile.lua:1: error\27[0m", "quickfix cleaning preserves output buffer")
assert_eq(quickfix.constructor({ tail = true }).on_pre_result({}, quickfix_task), nil, "tailed quickfix is not overwritten from output buffer")
assert_eq(#hooks, 1, "overseer setup registers one template hook")
assert_eq(hooks[1].filter.module, "^make$", "overseer setup forwards filter")

local task_defn = {}
hooks[1].callback(task_defn, {
  add_component = function(defn, component)
    defn.components = defn.components or {}
    defn.components[#defn.components + 1] = component
  end,
})
assert_eq(task_defn.components[1][1], "ansi_colorize", "overseer setup injects component")
assert_eq(task_defn.components[1].mode, "strip", "overseer setup forwards mode")
