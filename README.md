# term-color-parser.nvim

Colorize ANSI terminal output in regular Neovim buffers.

Many CLIs print color with ANSI SGR escape sequences like `\27[31m`. Those
sequences are useful in a terminal, but they are noisy in normal Neovim buffers.
This plugin parses them and applies native Neovim highlights.

## Features

- Pure Lua, no runtime dependencies.
- `:AnsiColorize [bufnr]` command for quick use.
- Lua API for plugin integrations.
- Conceal mode: keep ANSI codes in the buffer but hide them and highlight text.
- Strip mode: remove ANSI codes from the buffer and highlight the cleaned text.
- Optional Overseer.nvim component for task output buffers.
- Supports reset, bold, italic, underline, reverse, 16-color, 256-color, and
  truecolor foreground/background SGR sequences.

## Requirements

- Neovim 0.9 or newer.
- `conceallevel` support for non-destructive conceal mode.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "OWNER/term-color-parser.nvim",
  cmd = "AnsiColorize",
  config = true,
}
```

Replace `OWNER` with the GitHub owner after publishing the plugin.

## Configuration

The default setup is enough for manual use:

```lua
require("ansi-colorize").setup()
```

Enable the optional Overseer template hook:

```lua
require("ansi-colorize").setup({
  overseer = {
    preserve_ansi = true, -- keep ANSI until this plugin colorizes it
    mode = "conceal", -- "conceal" or "strip"
    on = "output",    -- "output" or "complete"
  },
})
```

## Usage

Colorize the current buffer without changing its text:

```vim
:AnsiColorize
```

Colorize a specific buffer:

```vim
:AnsiColorize 12
```

Strip ANSI codes and colorize the remaining text:

```vim
:AnsiColorize!
```

## Lua API

```lua
local ansi = require("ansi-colorize")

ansi.colorize(0) -- conceal ANSI codes and highlight text
ansi.strip(0)    -- remove ANSI codes and highlight text
ansi.clear(0)    -- remove plugin highlights
```

`0`, `nil`, or an omitted buffer number means the current buffer.

## Overseer.nvim

For all Overseer tasks, add the component to Overseer's default alias:

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

Use strip mode if you prefer permanent cleanup:

```lua
{ "ansi_colorize", mode = "strip", on = "complete" }
```

The `setup({ overseer = ... })` helper preserves ANSI in non-terminal output
before adding the component through Overseer's template hook. It only adds the
component to tasks created from templates; for every task, add it to
`component_aliases.default` as shown above. Set `preserve_ansi = false` to keep
Overseer's default output cleaning.

## Development

Run the integration tests:

```sh
make test
```

or:

```sh
sh scripts/test
```

The test suite runs in headless Neovim and covers the command, Lua API, parser,
buffer edits, extmark cleanup, and Overseer adapter.
