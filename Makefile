.PHONY: check test test-overseer

check: test test-overseer

test:
	sh tests/test

# Needs `git submodule update --init` and Neovim 0.11+.
test-overseer:
	sh tests/test-overseer
