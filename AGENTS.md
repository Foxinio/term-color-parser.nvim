# Repository Guidelines

## Project Structure & Module Organization

This repository contains a pure Lua Neovim plugin for colorizing ANSI SGR
terminal output in normal buffers.

- `lua/ansi-colorize/` contains the public Lua API and parser/highlighter.
- `lua/overseer/component/` contains optional Overseer.nvim components.
- `plugin/` registers Neovim commands loaded from `runtimepath`.
- `tests/` contains headless Neovim regression tests.
- `AGENTS.md` documents contributor expectations.

Keep Lua modules lowercase and path-based. Prefer adding focused helpers inside
`lua/ansi-colorize/init.lua` until splitting is clearly useful.

## Build, Test, and Development Commands

There is no build step. The plugin is loaded directly by Neovim.

- `make test`: run the headless Neovim integration tests.
- `sh tests/test`: run the same tests without relying on `make`.
- `nvim --clean +'set rtp+=.' +'AnsiColorize'`: manually load the plugin and
  run the command against the current buffer.
- Lazy.nvim example:

```lua
{ "yourname/term-color-parser.nvim", cmd = "AnsiColorize", config = true }
```

## Coding Style & Naming Conventions

Use two-space indentation. Prefer local functions and explicit module exports.
Public API names should stay action-oriented: `setup`, `colorize`, `strip`, and
`clear`. Keep third-party integrations optional and loaded only when configured
or required by the host plugin.

Avoid speculative abstractions. Add helpers only when multiple call sites need
the same behavior.

## Testing Guidelines

Tests are plain Lua files executed by headless Neovim through `tests/test`.
Add focused assertions for parser behavior, command behavior, Overseer adapter
behavior, buffer edits, and extmark cleanup. CI runs the same script in
`.github/workflows/ci.yml`.

Use descriptive test file names such as `tests/ansi_colorize_spec.lua`. Each bug
fix should include the smallest regression test that would fail without the fix.

## Commit & Pull Request Guidelines

Git history is not available in this workspace, so no repository-specific style
can be inferred. Use short, imperative commit subjects, for example
`Add ANSI reset parsing`.

Pull requests should include:

- A brief summary of the behavior changed.
- Test commands run.
- Screenshots only for visible UI or highlighting changes.

## Agent-Specific Instructions

Before editing, check whether requested files already exist. Do not overwrite
local work without explicit instruction.
