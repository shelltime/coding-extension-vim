-- shelltime.nvim - Automatic coding activity tracking for Neovim
-- https://github.com/shelltime/coding-extension-vim

local config = require('shelltime.config')
local heartbeat = require('shelltime.heartbeat')
local sender = require('shelltime.sender')

local M = {}

-- Plugin state
local initialized = false
local enabled = false

--- Initialize and start shelltime
local function start_tracking()
  if enabled then
    return
  end

  heartbeat.start()
  sender.start()
  enabled = true

  if config.get('debug') then
    vim.notify('[shelltime] Tracking started', vim.log.levels.INFO)
  end
end

--- Stop shelltime tracking
local function stop_tracking()
  if not enabled then
    return
  end

  -- Flush remaining heartbeats before stopping
  sender.flush()
  sender.stop()
  heartbeat.stop()
  enabled = false

  if config.get('debug') then
    vim.notify('[shelltime] Tracking stopped', vim.log.levels.INFO)
  end
end

--- Setup shelltime with user options
---@param opts table|nil Setup options
function M.setup(opts)
  if initialized then
    return
  end

  -- Initialize config
  config.setup(opts)

  -- Start tracking if enabled
  if config.is_enabled() then
    start_tracking()
  end

  initialized = true
end

--- Enable tracking
function M.enable()
  if not initialized then
    vim.notify('[shelltime] Call setup() first', vim.log.levels.ERROR)
    return
  end

  start_tracking()
end

--- Disable tracking
function M.disable()
  stop_tracking()
end

--- Check if tracking is enabled
---@return boolean
function M.is_enabled()
  return enabled
end

--- Force flush pending heartbeats
function M.flush()
  if not enabled then
    vim.notify('[shelltime] Tracking is not enabled', vim.log.levels.WARN)
    return
  end

  sender.flush(function(success, err)
    if success then
      vim.notify('[shelltime] Heartbeats flushed successfully', vim.log.levels.INFO)
    else
      vim.notify('[shelltime] Flush failed: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
    end
  end)
end

--- Show daemon connection status
function M.status()
  local pending = heartbeat.get_pending_count()

  sender.check_status(function(connected, status)
    if connected and status then
      local msg = string.format(
        '[shelltime] Connected to daemon\n' ..
        '  Version: %s\n' ..
        '  Uptime: %s\n' ..
        '  Platform: %s\n' ..
        '  Pending heartbeats: %d',
        status.version or 'unknown',
        status.uptime or 'unknown',
        status.platform or 'unknown',
        pending
      )
      vim.notify(msg, vim.log.levels.INFO)
    else
      vim.notify(
        string.format(
          '[shelltime] Disconnected from daemon\n' ..
          '  Socket: %s\n' ..
          '  Pending heartbeats: %d (queued)',
          config.get('socket_path'),
          pending
        ),
        vim.log.levels.WARN
      )
    end
  end)
end

return M
