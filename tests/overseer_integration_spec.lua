assert(vim.fn.has("nvim-0.11") == 1, "Overseer integration tests require Neovim 0.11+")

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(assert(vim.env.ANSI_COLORIZE_OVERSEER_PATH))

local util = require("overseer.util")
assert(require("ansi-colorize.overseer").preserve_overseer_ansi())

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "\27[31mlist output\27[0m" })
assert(util.get_last_output_lines(bufnr, 1)[1] == "list output")

local task = { get_bufnr = function() return bufnr end }
assert(require("overseer.render").output_lines(task)[1][2][1] == "list output")
