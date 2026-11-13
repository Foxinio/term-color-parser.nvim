# term-color-parser.nvim

Render ANSI terminal colors as native highlights in ordinary Neovim buffers.

Many CLIs print color with ANSI SGR escape sequences like `\27[31m`. Those
sequences are useful in a terminal, but they are noisy in normal Neovim buffers.
This plugin hides or removes the codes while preserving their colors and text
styles—without a terminal buffer, external process, or runtime dependency.

## Features

- Pure Lua, no runtime dependencies.
- `:AnsiColorize [bufnr]` command for quick use.
- Lua API for plugin integrations.
- Conceal mode: keep ANSI codes in the buffer but hide them and highlight text.
- Strip mode: remove ANSI codes from the buffer and highlight the cleaned text.
- Optional Overseer.nvim component for task output buffers.
- Supports reset, bold, dim, italic, underline styles and colors,
  strikethrough, reverse, 16-color, 256-color, and truecolor SGR sequences;
  16 and 256 colors also set the terminal palette index (`ctermfg`/`ctermbg`).
- A streaming decoder and string helpers for plugins that fill buffers
  themselves.

## Requirements

- Neovim 0.9 or newer (the Overseer integration is tested on 0.11+).
- `conceallevel` support for non-destructive conceal mode.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Foxinio/term-color-parser.nvim",
  cmd = "AnsiColorize",
  config = true,
}
```

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
    filter = {},      -- Overseer template hook filter, e.g. { module = "^make$" }
    enabled = true,   -- false skips the Overseer integration entirely
  },
})
```

With a lazily loaded plugin (`cmd = "AnsiColorize"`), Overseer only finds the
`ansi_colorize`, `force_color` and `strip_ansi_lines` components after the
plugin has loaded. Make it a dependency of overseer.nvim, or call `setup` from
overseer's config, if Overseer tasks use them.

Colour state carries across lines like in a terminal, and highlights are
re-applied after `:colorscheme`. `clear()` restores the window's
`conceallevel`/`concealcursor`. Strip mode temporarily makes nomodifiable
buffers modifiable; it refuses terminal buffers.

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

For output that arrives in chunks (a job's stdout, say), decode it before it
goes into the buffer, so the buffer only holds plain text:

```lua
local d = ansi.decoder()
-- for each chunk:
local text, spans = d:feed(chunk) -- text without escapes, spans {row, col, end_col, group}
-- append `text` to the buffer, then:
ansi.apply(bufnr, spans)          -- { row = n } when the stream starts at row n

local lines, spans = ansi.decode(text) -- a whole text at once
ansi.strip_text(text)                  -- a string without escape sequences
```

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
while keeping parsed output such as quickfix entries clean, then adds the
component through Overseer's template hook. It only adds the component to tasks
created from templates; for every task, add it to
`component_aliases.default` as shown above. Set `preserve_ansi = false` to keep
Overseer's default output cleaning.

While preserving ANSI, output buffers keep SGR codes (colours and text styles
such as bold, italic and underline). Other escape sequences only a terminal can
act on are removed: erase-line and cursor movement codes, and OSC sequences
such as compiler hyperlinks (the link text is kept) and window titles.

Two helper components are also provided:

- `force_color`: sets `CLICOLOR`, `CLICOLOR_FORCE`, `CMAKE_COLOR_DIAGNOSTICS`,
  `FORCE_COLOR`, `GTEST_COLOR`, `PY_COLORS` and `TERM` (existing task env wins),
  so tools emit colours even though output is not a terminal.
- `strip_ansi_lines`: removes every escape sequence from lines handed to later
  components. List it before line parsers such as `on_output_quickfix`.
