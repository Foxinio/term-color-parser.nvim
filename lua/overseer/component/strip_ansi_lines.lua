return {
  desc = "Strip ANSI escape sequences before line parsers consume output",
  constructor = function()
    return {
      on_output_lines = function(_, _, lines)
        local strip_all = require("ansi-colorize.overseer").strip_all
        for index, line in ipairs(lines) do
          lines[index] = strip_all(line)
        end
      end,
    }
  end,
}
