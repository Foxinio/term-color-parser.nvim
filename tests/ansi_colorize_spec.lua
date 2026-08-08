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

local overseer_component = dofile("lua/overseer/component/ansi_colorize.lua")
local overseer_buf = new_buf({ "\27[35mmagenta\27[0m" })
local fake_task = { get_bufnr = function() return overseer_buf end }
overseer_component.constructor({ mode = "conceal", on = "output" }):on_output(fake_task)
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
package.loaded.overseer = {
  add_template_hook = function(filter, callback)
    hooks[#hooks + 1] = { filter = filter, callback = callback }
  end,
}

local ok = require("ansi-colorize.overseer").setup({ mode = "strip", filter = { module = "^make$" } })
assert(ok, "overseer setup reports success when overseer is available")
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
