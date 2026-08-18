local M = {}

local defaults = {
  mode = "conceal",
  on = "output",
}

function M.component(opts)
  opts = vim.tbl_extend("force", defaults, opts or {})
  return { "ansi_colorize", mode = opts.mode, on = opts.on }
end

function M.preserve_overseer_ansi()
  -- ponytail: Overseer has no buffer-only ANSI hook; remove this patch if it adds one.
  local ok, util = pcall(require, "overseer.util")
  if not ok or util.__ansi_colorize_patched
      or type(util.clean_job_line) ~= "function"
      or type(util.get_stdout_line_iter) ~= "function" then
    return false
  end

  local clean_job_line = util.clean_job_line
  local get_stdout_line_iter = util.get_stdout_line_iter

  util.__ansi_colorize_patched = true
  util.clean_job_line = function(str)
    return str:gsub("\r$", "")
  end
  util.get_stdout_line_iter = function()
    local iter = get_stdout_line_iter()
    return function(data)
      return vim.tbl_map(clean_job_line, iter(data))
    end
  end

  return true
end

function M.setup(opts)
  opts = opts == true and {} or opts or {}
  if opts.enabled == false then
    return false
  end

  if opts.preserve_ansi ~= false then
    M.preserve_overseer_ansi()
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
