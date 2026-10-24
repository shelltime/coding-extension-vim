-- Unix socket client for shelltime daemon communication

local config = require('shelltime.config')

local M = {}

-- Socket timeout in milliseconds
local SOCKET_TIMEOUT = 5000

--- Send message to daemon via Unix socket
---@param message table Message to send
---@param callback function Callback(response, error)
function M.send(message, callback)
  local uv = vim.loop or vim.uv
  local socket_path = config.get('socket_path')
  local pipe = uv.new_pipe(false)

  -- A timeout and a late reply can both be scheduled; only the first one counts
  local done = false
  local user_callback = callback
  callback = function(...)
    if done then
      return
    end
    done = true
    user_callback(...)
  end

  if not pipe then
    callback(nil, 'Failed to create pipe')
    return
  end

  local response_data = ''
  local timeout_timer = nil
  local closed = false

  local function cleanup()
    if closed then
      return
    end
    closed = true

    if timeout_timer then
      timeout_timer:stop()
      timeout_timer:close()
    end

    if pipe then
      pipe:read_stop()
      if not pipe:is_closing() then
        pipe:close()
      end
    end
  end

  -- Set timeout
  timeout_timer = uv.new_timer()
  timeout_timer:start(SOCKET_TIMEOUT, 0, function()
    vim.schedule(function()
      cleanup()
      callback(nil, 'Connection timeout')
    end)
  end)

  pipe:connect(socket_path, function(err)
    if err then
      vim.schedule(function()
        cleanup()
        callback(nil, 'Connection failed: ' .. err)
      end)
      return
    end

    -- Send message (use vim.json.encode for fast event context)
    local json_msg = vim.json.encode(message)
    pipe:write(json_msg, function(write_err)
      if write_err then
        vim.schedule(function()
          cleanup()
          callback(nil, 'Write failed: ' .. write_err)
        end)
        return
      end

      -- Signal end of write
      pipe:shutdown(function()
        -- Start reading response
        pipe:read_start(function(read_err, data)
          if read_err then
            vim.schedule(function()
              cleanup()
              callback(nil, 'Read failed: ' .. read_err)
            end)
            return
          end

          if data then
            response_data = response_data .. data
          else
            -- EOF - parse response
            vim.schedule(function()
              cleanup()
              if response_data ~= '' then
                local ok, parsed = pcall(vim.json.decode, response_data)
                if ok then
                  callback(parsed, nil)
                else
                  callback(nil, 'Failed to parse response')
                end
              else
                callback(nil, nil) -- Closed without a reply
              end
            end)
          end
        end)
      end)
    end)
  end)
end

--- Send heartbeats to daemon
---@param heartbeats table[] Array of heartbeat data
---@param callback function Callback(status, error): status is 'ok', 'disabled' when
--- the daemon dropped them because code tracking is off in its config, or 'failed'
function M.send_heartbeats(heartbeats, callback)
  local message = {
    type = 'heartbeat',
    payload = {
      heartbeats = heartbeats,
    },
  }

  M.send(message, function(response, err)
    if err then
      callback('failed', err)
    elseif response == nil then
      -- Daemons since 0.1.48 acknowledge every heartbeat message and close
      -- without a reply when they could not take it (shutting down, or dying
      -- before they answer), so the heartbeats must be kept. 0.1.42-0.1.47
      -- handled heartbeats but never replied (0.1.42 answers no status
      -- either): an empty reply counts as delivered only when the daemon
      -- still takes connections, which a stopping one no longer does.
      M.can_connect(function(connected)
        if connected then
          callback('ok', nil)
        else
          callback('failed', 'no acknowledgment from the daemon')
        end
      end)
    elseif type(response) == 'table' and response.status == 'disabled' then
      callback('disabled', 'code tracking is disabled in the daemon')
    else
      callback('ok', nil)
    end
  end)
end

--- Check that the daemon takes connections, without sending it anything
---@param callback function Callback(connected)
function M.can_connect(callback)
  local uv = vim.loop or vim.uv
  local pipe = uv.new_pipe(false)
  if not pipe then
    callback(false)
    return
  end

  local done = false
  local timer = uv.new_timer()
  local function finish(connected)
    if done then
      return
    end
    done = true
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    if not pipe:is_closing() then
      pipe:close()
    end
    vim.schedule(function()
      callback(connected)
    end)
  end

  timer:start(SOCKET_TIMEOUT, 0, function()
    finish(false)
  end)
  pipe:connect(config.get('socket_path'), function(err)
    finish(err == nil)
  end)
end

--- Get daemon status
---@param callback function Callback(status, error)
function M.get_status(callback)
  local message = {
    type = 'status',
    payload = vim.NIL,
  }

  M.send(message, callback)
end

--- Check if daemon is connected (synchronous check)
---@return boolean
function M.is_connected_sync()
  local uv = vim.loop or vim.uv
  local socket_path = config.get('socket_path')
  local stat = uv.fs_stat(socket_path)
  return stat ~= nil
end

return M
