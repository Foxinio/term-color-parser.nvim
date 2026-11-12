vim.api.nvim_create_user_command("AnsiColorize", function(args)
  local ansi = require("ansi-colorize")
  local bufnr = args.args ~= "" and tonumber(args.args) or nil

  if args.args ~= "" and not bufnr then
    error("AnsiColorize expects a buffer number")
  end

  ansi.colorize(bufnr, { strip = args.bang })
end, {
  bang = true,
  nargs = "?",
  complete = function()
    return vim.tbl_map(tostring, vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.api.nvim_list_bufs()))
  end,
  desc = "Colorize ANSI SGR escape sequences in a buffer",
})
