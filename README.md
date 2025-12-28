# shelltime.nvim

A Neovim plugin for automatic coding activity tracking. Works with the ShellTime daemon to monitor your development time across projects.

## Features

- **Automatic Time Tracking** - Passively monitors coding activity
- **Language Detection** - Auto-detects programming language from filetype
- **Project Analytics** - Tracks time per project/workspace
- **Git Integration** - Records activity by git branch
- **Event Debouncing** - Efficient heartbeat batching (30s cooldown per file)
- **Offline Support** - Queues heartbeats when daemon unavailable

## Requirements

- Neovim >= 0.10.0
- ShellTime daemon running (`/tmp/shelltime.sock`)
- Git (optional, for branch tracking)

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

Then add to your `init.lua`:

```lua
require("shelltime").setup()
```

## Quick Start

1. **Install the ShellTime daemon** - Make sure the daemon is running and listening on `/tmp/shelltime.sock`

2. **Create config file** at `~/.shelltime/config.yaml`:

```yaml
socketPath: /tmp/shelltime.sock
codeTracking:
  enabled: true
```

3. **Install the plugin** using your preferred plugin manager (see above)

4. **Start coding** - The plugin automatically tracks your activity!

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

### Config File Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `socketPath` | string | `/tmp/shelltime.sock` | Unix socket path for daemon |
| `codeTracking.enabled` | boolean | `true` | Enable/disable tracking |
| `debug` | boolean | `false` | Enable debug logging |

Example `~/.shelltime/config.yaml`:

```yaml
socketPath: /tmp/shelltime.sock
codeTracking:
  enabled: true
debug: false
```

## Commands

| Command | Description |
|---------|-------------|
| `:ShellTimeStatus` | Show daemon connection status and pending heartbeats |
| `:ShellTimeFlush` | Manually flush pending heartbeats to daemon |
| `:ShellTimeEnable` | Enable tracking |
| `:ShellTimeDisable` | Disable tracking |

## Usage Examples

### Check Connection Status

```vim
:ShellTimeStatus
```

This shows:
- Whether the daemon is connected
- Daemon version and uptime
- Number of pending heartbeats

### Temporarily Disable Tracking

```vim
:ShellTimeDisable
" ... do some work you don't want tracked ...
:ShellTimeEnable
```

### Force Send Pending Data

```vim
:ShellTimeFlush
```

Useful before closing Neovim to ensure all data is sent.

## How It Works

The plugin monitors these Neovim events:

| Event | Trigger |
|-------|---------|
| `BufEnter` | Opening a file |
| `TextChanged` / `TextChangedI` | Editing text |
| `BufWritePost` | Saving a file |
| `CursorMoved` / `CursorMovedI` | Moving cursor |

Heartbeats are:
- **Debounced**: Max 1 heartbeat per file per 30 seconds (except saves)
- **Batched**: Sent to daemon every 2 minutes
- **Queued**: Stored locally if daemon is unavailable

### Data Tracked

Each heartbeat includes:

- **File info**: Path, language, line count, cursor position
- **Project info**: Name, root path, git branch
- **Editor info**: Neovim version, plugin version
- **System info**: Hostname, OS, OS version
- **Activity**: Timestamp, whether it was a save event

## Troubleshooting

### Plugin not tracking

1. Check if daemon is running:
   ```bash
   ls -la /tmp/shelltime.sock
   ```

2. Verify config file exists:
   ```bash
   cat ~/.shelltime/config.yaml
   ```

3. Enable debug mode in config:
   ```yaml
   debug: true
   ```

4. Check status in Neovim:
   ```vim
   :ShellTimeStatus
   ```

### Heartbeats not sending

Run `:ShellTimeStatus` to check:
- If "Disconnected", ensure daemon is running
- If pending heartbeats > 0, try `:ShellTimeFlush`

## License

GPL-3.0
