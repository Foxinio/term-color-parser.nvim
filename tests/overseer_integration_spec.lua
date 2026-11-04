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
