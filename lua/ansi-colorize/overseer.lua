local M = {}

local defaults = {
  mode = "conceal",
  on = "output",
}

function M.component(opts)
  opts = vim.tbl_extend("force", defaults, opts or {})
  return { "ansi_colorize", mode = opts.mode, on = opts.on }
end

function M.setup(opts)
  opts = opts == true and {} or opts or {}
  if opts.enabled == false then
    return false
  end

  local ok, overseer = pcall(require, "overseer")
  if not ok or type(overseer.add_template_hook) ~= "function" then
    return false
  end

  overseer.add_template_hook(opts.filter or {}, function(task_defn, util)
    util.add_component(task_defn, M.component(opts))
  end)

  return true
end

return M
