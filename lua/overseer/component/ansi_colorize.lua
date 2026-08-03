local function colorize_task(task, mode)
  local bufnr = task:get_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ansi = require("ansi-colorize")
  if mode == "strip" then
    ansi.strip(bufnr)
  else
    ansi.colorize(bufnr)
  end
end

local function schedule_colorize(task, mode)
  vim.schedule(function()
    colorize_task(task, mode)
  end)
end

return {
  desc = "Colorize ANSI SGR escape sequences in Overseer output",
  params = {
    mode = {
      type = "enum",
      choices = { "conceal", "strip" },
      default = "conceal",
      desc = "Whether to hide or remove ANSI escape sequences",
    },
    on = {
      type = "enum",
      choices = { "output", "complete" },
      default = "output",
      desc = "When to colorize the output buffer",
    },
  },
  constructor = function(params)
    params = vim.tbl_extend("force", { mode = "conceal", on = "output" }, params or {})

    return {
      on_start = function(_, task)
        schedule_colorize(task, params.mode)
      end,
      on_output = function(_, task)
        if params.on == "output" then
          schedule_colorize(task, params.mode)
        end
      end,
      on_complete = function(_, task)
        schedule_colorize(task, params.mode)
      end,
    }
  end,
}
