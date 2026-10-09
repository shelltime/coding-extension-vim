<p align="center">
  <img src="assets/logo.svg" alt="ShellTime logo" width="96" height="96">
</p>

# shelltime.nvim

[![CI](https://github.com/shelltime/coding-extension-vim/actions/workflows/ci.yml/badge.svg)](https://github.com/shelltime/coding-extension-vim/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/shelltime/coding-extension-vim/branch/main/graph/badge.svg)](https://codecov.io/gh/shelltime/coding-extension-vim)

A Neovim plugin for automatic coding activity tracking. Works with the ShellTime daemon to monitor your development time across projects.

## Features

- **Automatic Time Tracking** - Passively monitors coding activity
- **Language Detection** - Uses the buffer's filetype, falling back to the file extension
- **Project Analytics** - Tracks time per project/workspace
- **Git Integration** - Records activity by git branch
- **Debug Detection** - Marks activity as `debugging` while an nvim-dap session is active
- **Debouncing & Batching** - At most one heartbeat per file every 30s (saves always count), sent in batches every 2 minutes
- **Offline Support** - Keeps heartbeats in memory and retries them when the daemon is unavailable
- **Flush on Exit** - Sends pending heartbeats when Neovim quits, so short sessions aren't lost
- **CLI Update Check** - Warns once per session when your ShellTime CLI is out of date

## Prerequisites

### 1. Install ShellTime CLI

```bash
curl -sSL https://shelltime.xyz/i | bash
```

After installation, reload your shell configuration:
- **zsh**: `source ~/.zshrc`
- **fish**: `source ~/.config/fish/config.fish`
- **bash**: `source ~/.bashrc`

### 2. Initialize and Authenticate

```bash
shelltime init
```

This will:
- Open your browser to authenticate with your ShellTime account
- Install shell hooks for your shell (zsh/fish/bash)
- Start the ShellTime daemon

### 3. Enable Code Tracking

Make sure your ShellTime config (`~/.shelltime/config.yaml`) contains:

```yaml
codeTracking:
  enabled: true
```

Or in TOML format (`~/.shelltime/config.toml`):

```toml
[codeTracking]
enabled = true
```

Configs created by `shelltime init` already include this; older configs may not. The daemon ignores editor heartbeats unless it is `true`, and it reads the setting at startup, so restart the daemon after changing it (for example with `shelltime daemon reinstall`).

## Requirements

- Neovim >= 0.10.0 (Neovim only; classic Vim isn't supported)
- ShellTime daemon running (see [Prerequisites](#prerequisites))
- Git (optional, for branch tracking)
- `curl` (optional, for the CLI update check)

## Installation

### lazy.nvim

```lua
{
  "shelltime/coding-extension-vim",
  event = "VeryLazy",
  opts = {},
}
```

### packer.nvim

```lua
use {
  "shelltime/coding-extension-vim",
  config = function()
    require("shelltime").setup()
  end
}
```

### vim-plug

```vim
Plug 'shelltime/coding-extension-vim'
```

Then add to your `init.lua` (or `lua require("shelltime").setup()` to `init.vim`):

```lua
require("shelltime").setup()
```

Calling `setup()` is required: loading the plugin only registers its commands. With lazy.nvim, `opts = {}` calls it for you.

## Quick Start

1. **Complete the [Prerequisites](#prerequisites)** - Install CLI, authenticate, and enable code tracking

2. **Install the plugin** using your preferred plugin manager (see above)

3. **Start coding** - The plugin automatically tracks your activity!

## Configuration

The plugin reads settings from `~/.shelltime/config.yaml` by default:

```lua
-- Default setup (uses ~/.shelltime/config.yaml)
require("shelltime").setup()

-- Custom config path
require("shelltime").setup({
  config = "/path/to/your/config.yaml",
})
```

`config` is the only `setup()` option. The plugin reads just this one YAML file: not `config.toml`, `config.yml` or `config.local.*`. If the file is missing, it uses the defaults below. The file is re-read whenever it changes, so most settings apply without restarting Neovim (`heartbeatInterval` needs a restart).

### Config File Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `socketPath` | string | `/tmp/shelltime.sock` | Unix socket path for daemon |
| `codeTracking.enabled` | boolean | `true` | Enable/disable tracking in the plugin. The daemon also requires it to be `true` (see [Prerequisites](#3-enable-code-tracking)) |
| `debug` | boolean | `false` | Enable debug logging |
| `heartbeatInterval` | number | `120000` | How often pending heartbeats are sent, in ms |
| `debounceInterval` | number | `30000` | Minimum time between heartbeats for the same file, in ms |
| `apiEndpoint` | string | - | ShellTime API URL used for the CLI update check (written by `shelltime init`) |
| `webEndpoint` | string | - | ShellTime web URL used in the update command (written by `shelltime init`) |

## Commands

| Command | Description |
|---------|-------------|
| `:ShellTimeStatus` | Show daemon connection status (version, uptime, platform) and pending heartbeats |
| `:ShellTimeFlush` | Manually flush pending heartbeats to daemon |
| `:ShellTimeEnable` | Enable tracking for this session (needs `setup()`; doesn't override `codeTracking.enabled: false`) |
| `:ShellTimeDisable` | Flush pending heartbeats and disable tracking for this session |

## How It Works

The plugin monitors these Neovim events:

| Event | Trigger |
|-------|---------|
| `BufEnter` | Opening or switching to a file |
| `TextChanged` / `TextChangedI` | Editing text |
| `BufWritePost` | Saving a file |
| `CursorMoved` / `CursorMovedI` | Moving cursor |

Only regular files are tracked. Special buffers (help, terminal, quickfix, etc.), unnamed buffers, files inside `.git/`, and non-`file://` URLs such as `oil://` or `fugitive://` are skipped.

Heartbeats are:
- **Deduplicated**: Buffer and cursor events at the same file and cursor position as the last event are skipped (edits always count)
- **Debounced**: Max 1 heartbeat per file per 30 seconds (except saves)
- **Batched**: Sent to the daemon over its Unix socket every 2 minutes
- **Flushed on exit**: Pending heartbeats are sent on `VimLeavePre` (Neovim waits up to 1.5s)
- **Queued**: Kept in memory and retried on the next flush if the daemon is unavailable (up to 5,000; oldest dropped first). They are not written to disk, so they are lost if Neovim exits while the daemon is down

### Data Tracked

Each heartbeat includes:

- **File info**: Path, language, line count, cursor position
- **Project info**: Name, root path, git branch
- **Editor info**: Neovim version, plugin version
- **System info**: Hostname, OS, OS version
- **Activity**: Timestamp, whether it was a save event, category (`coding` or `debugging`)

The project root is the nearest parent directory containing `.git`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `setup.py`, `Makefile`, `CMakeLists.txt`, `.project` or `.root` (otherwise the file's directory). The project name is its last two path segments, e.g. `code/my-app`.

### CLI Update Check

On startup, if the daemon is reachable, the plugin asks `<apiEndpoint>/api/v1/cli/version-check` (via `curl`) whether the daemon's CLI version is the latest. If not, it shows a warning once per session with the update command (`curl -sSL <webEndpoint>/i | bash`) and copies that command to the `+` register when a clipboard is available. The check is skipped when `apiEndpoint` or `webEndpoint` is not set.

## Troubleshooting

### Plugin not tracking

1. Check if daemon is running:
   ```bash
   shelltime daemon status   # socket, running state, and whether Code Tracking is enabled
   # If not running, run: shelltime init
   ```

2. Verify config file exists:
   ```bash
   cat ~/.shelltime/config.yaml
   ```

3. Enable debug mode in config (messages are shown via `vim.notify`):
   ```yaml
   debug: true
   ```

4. Check status in Neovim:
   ```vim
   :ShellTimeStatus
   ```

### Heartbeats not sending

Run `:ShellTimeStatus` to check:
- If "Disconnected", ensure daemon is running and `socketPath` matches the daemon's socket
- If pending heartbeats > 0, try `:ShellTimeFlush`
- If "Connected" and flushes succeed but no activity shows up, check that `codeTracking.enabled` is `true` for the daemon and restart it. The daemon drops heartbeats otherwise, and the plugin can't tell

## License

[GPL-3.0](LICENSE)
