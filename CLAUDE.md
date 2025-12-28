# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Neovim plugin for coding activity tracking, written in Lua. Communicates with ShellTime daemon via Unix socket.

## Development Commands

```bash
# Run all tests (requires plenary.nvim)
./scripts/test.sh

# Run a single test file
./scripts/test.sh tests/heartbeat_spec.lua

# Run tests with coverage (requires luacov)
./scripts/test-coverage.sh
```

## Architecture

```
lua/shelltime/
  init.lua          -- Entry point: setup(), enable/disable, status, flush
  config.lua        -- YAML config loading from ~/.shelltime/config.yaml
  heartbeat.lua     -- Autocmd event handling, heartbeat creation, debouncing
  sender.lua        -- Timer-based batching, socket communication
  socket.lua        -- Unix socket client (vim.loop/libuv)
  utils/
    git.lua         -- Git branch detection
    system.lua      -- OS/hostname info
    yaml.lua        -- Minimal YAML parser

plugin/shelltime.lua  -- Auto-load, user commands (:ShellTimeStatus, etc.)
```

**Data flow**: Neovim events → heartbeat.lua (debounce) → sender.lua (batch) → socket.lua → daemon

## Coding Conventions

- 2-space indentation, `local` for all variables
- snake_case for functions/variables, PascalCase for module tables
- Single quotes for strings
- Use `vim.api.nvim_*` for buffer/window, `vim.fn.*` for Vimscript, `vim.loop` for async I/O
- Error handling: `pcall()` for operations that may fail, never crash on socket failures

## Testing

- Framework: plenary.nvim (busted-style)
- Test files: `tests/*_spec.lua`
- Helpers: `tests/helpers/` (mock_vim.lua, fixtures.lua, reset.lua)
- Pattern: Reset modules in `before_each`, use stubs from `luassert.stub`

## Key Constants

- Config path: `~/.shelltime/config.yaml`
- Socket path: `/tmp/shelltime.sock`
- Heartbeat interval: 120000ms (2 min)
- Debounce interval: 30000ms (30 sec)

## Commit Rules

Follow Conventional Commits with scope:

```
feat(heartbeat): add cursor position tracking
fix(socket): handle connection timeout gracefully
refactor(config): simplify YAML parsing logic
perf(sender): reduce timer overhead
```
