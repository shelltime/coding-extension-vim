# shelltime.nvim Development Guidelines

## Project Overview

Neovim plugin for coding activity tracking, written in Lua. Communicates with
ShellTime daemon via Unix socket.

## Directory Structure

```
lua/
  shelltime/
    init.lua          -- Main entry, setup(), public API
    config.lua        -- Configuration loading (YAML)
    heartbeat.lua     -- Heartbeat data creation & collection
    sender.lua        -- Periodic flush & socket communication
    socket.lua        -- Unix socket client
    utils/
      init.lua        -- Utility exports
      git.lua         -- Git branch detection
      system.lua      -- OS/hostname info
      yaml.lua        -- Minimal YAML parser
plugin/
  shelltime.lua       -- Auto-load & command registration
```

## Coding Conventions

### Lua Style

- Use `local` for all variables
- 2-space indentation
- snake_case for functions/variables
- PascalCase for module tables only
- Single quotes for strings (except when containing quotes)
- Document public functions with LuaDoc comments

### Neovim API Patterns

- Use `vim.api.nvim_*` for buffer/window operations
- Use `vim.fn.*` for Vimscript functions
- Use `vim.loop` (libuv) for async I/O and timers
- Use `vim.schedule()` for safe main-thread callbacks
- Use `vim.notify()` for user messages

### Error Handling

- Use `pcall()` for operations that may fail
- Log errors with `vim.notify(msg, vim.log.levels.ERROR)`
- Never crash on socket/network failures

## Events to Monitor

- `BufEnter` - File opened
- `TextChanged`, `TextChangedI` - Text edited
- `BufWritePost` - File saved (always send, bypass debounce)
- `CursorMoved`, `CursorMovedI` - Cursor movement

## Commit Rules

Follow Conventional Commits with scope:

```
feat(heartbeat): add cursor position tracking
fix(socket): handle connection timeout gracefully
refactor(config): simplify YAML parsing logic
perf(sender): reduce timer overhead
```

## Testing

- Use plenary.nvim for testing
- Test files: `tests/*_spec.lua`
- Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`

## Key Constants

- Config path: `~/.shelltime/config.yaml`
- Socket path: `/tmp/shelltime.sock` (from YAML)
- Heartbeat interval: 120000ms (2 min)
- Debounce interval: 30000ms (30 sec)
- Socket timeout: 5000ms
