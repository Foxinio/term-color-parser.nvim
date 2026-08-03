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
  complete = "buffer",
  desc = "Colorize ANSI SGR escape sequences in a buffer",
})
