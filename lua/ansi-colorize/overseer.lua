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

  local overseer_clean_job_line = util.clean_job_line
  local get_stdout_line_iter = util.get_stdout_line_iter
  local function clean_job_line(str)
    return (overseer_clean_job_line(str):gsub("\27%[[%d;:]*m", ""))
  end

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

  local qf_ok, components = pcall(require, "overseer.component")
  local qf = qf_ok and type(components.get) == "function" and components.get("on_output_quickfix")
  if qf_ok and type(qf.constructor) == "function" and not qf.__ansi_colorize_patched then
    local constructor = qf.constructor
    qf.__ansi_colorize_patched = true
    qf.constructor = function(params)
      local component = constructor(params)
      local on_pre_result = component.on_pre_result
      component.on_pre_result = function(self, task)
        local bufnr = task:get_bufnr()
        if not bufnr or vim.bo[bufnr].buftype == "terminal" then
          return on_pre_result(self, task)
        elseif params.tail then
          return
        end

        local clean_bufnr = vim.api.nvim_create_buf(false, true)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
        vim.api.nvim_buf_set_lines(clean_bufnr, 0, -1, true, vim.tbl_map(clean_job_line, lines))
        local clean_task = setmetatable({
          get_bufnr = function()
            return clean_bufnr
          end,
        }, { __index = task })
        local ok, result = pcall(on_pre_result, self, clean_task)
        vim.api.nvim_buf_delete(clean_bufnr, { force = true })
        if not ok then
          error(result)
        end
        return result
      end
      return component
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
