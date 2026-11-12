assert(vim.fn.has("nvim-0.11") == 1, "Overseer integration tests require Neovim 0.11+")

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(assert(vim.env.ANSI_COLORIZE_OVERSEER_PATH))

local util = require("overseer.util")
assert(require("ansi-colorize.overseer").preserve_overseer_ansi())

local output
local job = vim.fn.jobstart({ "sh", "-c", "printf '\\033[31mred\\000tail\\033[0m\\r\\n'" }, {
  stdout_buffered = true,
  on_stdout = function(_, data)
    output = data
  end,
})
assert(job > 0, "NUL output job starts")
assert(vim.fn.jobwait({ job }, 5000)[1] == 0, "NUL output job succeeds")
assert(output and output[1] == "\27[31mred\ntail\27[0m\r", "job callback encodes NUL as newline")
local cleaned = vim.tbl_map(util.clean_job_line, output)
assert(cleaned[1] == "\27[31mred\0tail\27[0m", "cleaner restores NUL and preserves ANSI")
local output_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, true, cleaned)
assert(vim.api.nvim_buf_get_lines(output_bufnr, 0, -1, true)[1] == cleaned[1], "NUL output can be inserted into a buffer")

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "\27[31mlist output\27[0m" })
assert(util.get_last_output_lines(bufnr, 1)[1] == "list output")

local task = { get_bufnr = function() return bufnr end }
assert(require("overseer.render").output_lines(task)[1][2][1] == "list output")

local ov = require("ansi-colorize.overseer")
local noisy = "\27[1;31merror\27[0m\27[K: \27]8;;file:///a.c\7a.c\27]8;;\7 x\27]8;;u\27\\y\27]8;;\27\\"
assert(ov.strip_non_sgr(noisy) == "\27[1;31merror\27[0m: a.c xy", "non-SGR escapes stripped, colours kept")
assert(ov.strip_all(noisy) == "error: a.c xy", "all escapes stripped")
assert(util.clean_job_line(noisy) == "\27[1;31merror\27[0m: a.c xy", "buffer lines keep only colours")

local components = require("overseer.component")
for _, name in ipairs({ "ansi_colorize", "force_color", "strip_ansi_lines" }) do
  assert(components.get(name), "component " .. name .. " is available")
end
local lines = { noisy }
components.get("strip_ansi_lines").constructor({}).on_output_lines(nil, nil, lines)
assert(lines[1] == "error: a.c xy", "strip_ansi_lines removes every escape")
local task = { env = { TERM = "dumb" } }
components.get("force_color").constructor({}).on_init(nil, task)
assert(task.env.TERM == "dumb" and task.env.FORCE_COLOR == "1", "force_color keeps existing env")
print("overseer integration tests passed")
