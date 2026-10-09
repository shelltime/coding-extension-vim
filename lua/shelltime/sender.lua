-- Heartbeat sender for shelltime

local config = require('shelltime.config')
local socket = require('shelltime.socket')
local heartbeat = require('shelltime.heartbeat')
local version = require('shelltime.version')

local M = {}

-- Flush timer
local flush_timer = nil

-- Autocmd group for the exit flush
local augroup = nil

-- How long Neovim may wait on exit for pending heartbeats to be sent
local EXIT_FLUSH_TIMEOUT = 1500

-- Connection status
local is_connected = false

--- Send pending heartbeats to daemon
---@param callback function|nil Optional callback(success, error)
local function send_heartbeats(callback)
  local heartbeats = heartbeat.flush()

  if #heartbeats == 0 then
    if callback then
      callback(true, nil)
    end
    return
  end

  socket.send_heartbeats(heartbeats, function(success, err)
    is_connected = success

    if not success then
      -- Keep them for the next flush instead of dropping them
      heartbeat.requeue(heartbeats)
    end

    if config.get('debug') then
      if success then
        vim.notify(
          string.format('[shelltime] Sent %d heartbeats', #heartbeats),
          vim.log.levels.DEBUG
        )
      else
        vim.notify(
          string.format('[shelltime] Failed to send heartbeats: %s', err or 'unknown'),
          vim.log.levels.WARN
        )
      end
    end

    if callback then
      callback(success, err)
    end
  end)
end

--- Start periodic flush timer
function M.start()
  if flush_timer then
    return -- Already started
  end

  local uv = vim.loop or vim.uv
  local interval = config.get('heartbeat_interval')

  flush_timer = uv.new_timer()
  flush_timer:start(interval, interval, function()
    vim.schedule(function()
      send_heartbeats()
    end)
  end)

  -- Sessions are often shorter than the flush interval, so send what is
  -- pending before Neovim exits.
  augroup = vim.api.nvim_create_augroup('ShellTimeSender', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      M.flush_sync(EXIT_FLUSH_TIMEOUT)
    end,
  })

  -- Check initial connection status and CLI version
  vim.schedule(function()
    is_connected = socket.is_connected_sync()

    -- Check CLI version in background (non-blocking)
    if is_connected then
      socket.get_status(function(status, err)
        if status and status.version then
          version.check_version(status.version)
        end
      end)
    end
  end)
end

--- Stop flush timer
function M.stop()
  if flush_timer then
    flush_timer:stop()
    flush_timer:close()
    flush_timer = nil
  end

  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end
end

--- Force flush pending heartbeats
---@param callback function|nil Optional callback(success, error)
function M.flush(callback)
  send_heartbeats(callback)
end

--- Flush pending heartbeats and block until sent or timed out
---@param timeout number Maximum wait in milliseconds
---@return boolean True if the send finished within the timeout
function M.flush_sync(timeout)
  local done = false
  send_heartbeats(function()
    done = true
  end)
  return vim.wait(timeout, function()
    return done
  end, 10)
end

--- Get connection status
---@return boolean
function M.is_connected()
  return is_connected
end

--- Check and update connection status
---@param callback function Callback(connected)
function M.check_status(callback)
  socket.get_status(function(status, err)
    is_connected = err == nil and status ~= nil
    callback(is_connected, status)
  end)
end

return M
