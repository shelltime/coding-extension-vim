-- Heartbeat sender for shelltime

local config = require('shelltime.config')
local socket = require('shelltime.socket')
local heartbeat = require('shelltime.heartbeat')

local M = {}

-- Flush timer
local flush_timer = nil

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

  -- Check initial connection status
  vim.schedule(function()
    is_connected = socket.is_connected_sync()
  end)
end

--- Stop flush timer
function M.stop()
  if flush_timer then
    flush_timer:stop()
    flush_timer:close()
    flush_timer = nil
  end
end

--- Force flush pending heartbeats
---@param callback function|nil Optional callback(success, error)
function M.flush(callback)
  send_heartbeats(callback)
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
