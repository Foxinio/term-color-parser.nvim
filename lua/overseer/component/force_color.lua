return {
  desc = "Ask commands to emit colored output",
  constructor = function()
    return {
      on_init = function(_, task)
        task.env = vim.tbl_extend("keep", task.env or {}, {
          CLICOLOR = "YES",
          CLICOLOR_FORCE = "YES",
          CMAKE_COLOR_DIAGNOSTICS = "ON",
          FORCE_COLOR = "1",
          GTEST_COLOR = "1",
          PY_COLORS = "1",
          TERM = "xterm-256color",
        })
      end,
    }
  end,
}
