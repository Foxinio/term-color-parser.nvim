# term-color-parser.nvim

Colorize ANSI SGR terminal output in regular Neovim buffers.

## Install

With Lazy.nvim:

```lua
{
  "yourname/term-color-parser.nvim",
  cmd = "AnsiColorize",
  config = true,
}
```

## Usage

Colorize the current buffer without changing its text:

```vim
:AnsiColorize
```

Colorize another buffer:

```vim
:AnsiColorize 12
```

Remove ANSI escape sequences from the buffer and apply highlights to the
remaining text:

```vim
:AnsiColorize!
```

Lua API:

```lua
local ansi = require("ansi-colorize")

ansi.colorize(0) -- conceal escape codes and highlight text
ansi.strip(0)    -- remove escape codes and highlight text
ansi.clear(0)    -- remove plugin highlights
```

Supported styling includes reset, bold, italic, underline, reverse, 16-color,
256-color, and truecolor foreground/background SGR sequences.

## Overseer.nvim

To colorize Overseer output buffers, add the bundled component to Overseer:

```lua
require("overseer").setup({
  component_aliases = {
    default = {
      "on_exit_set_status",
      "on_complete_notify",
      { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
      { "ansi_colorize", mode = "conceal", on = "output" },
    },
  },
})
```

Configure the component per task or alias:

```lua
{ "ansi_colorize", mode = "conceal", on = "output" }
{ "ansi_colorize", mode = "strip", on = "complete" }
```

You can also ask this plugin to add the component to Overseer templates:

```lua
require("ansi-colorize").setup({
  overseer = {
    enabled = true,
    mode = "conceal",
    on = "output",
  },
})
```

The setup hook only affects tasks created from templates. For every Overseer
task, prefer the `component_aliases.default` configuration above.

## Tests

Run the integration tests with:

```sh
make test
```

or directly:

```sh
sh scripts/test
```
