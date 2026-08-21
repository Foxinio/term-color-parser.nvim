# Tests

Run the plugin regression suite with:

```sh
make test
```

The equivalent command without Make is `sh tests/test`. It starts an isolated,
headless Neovim and covers the command, Lua API, parser, buffer edits, extmark
cleanup, and the mocked Overseer adapter.

## Overseer integration

Overseer.nvim is pinned in `third_party/overseer.nvim` as a Git submodule. For
an existing clone, initialize it with:

```sh
git submodule update --init --recursive
```

For a new clone, `git clone --recurse-submodules <repository>` fetches it at the
same time. Overseer's core has no additional plugin dependencies.

Run the test against Overseer's real API with Neovim 0.11 or newer:

```sh
sh tests/test-overseer
```

The script uses only the pinned checkout; it does not inspect Neovim's installed
plugins. It verifies that ANSI is preserved in task buffers but removed from
the copied output rendered in `OverseerList`.
