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
                callback(nil, nil) -- Empty response is ok for heartbeats
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
---@param callback function Callback(success, error)
function M.send_heartbeats(heartbeats, callback)
  local message = {
    type = 'heartbeat',
    payload = {
      heartbeats = heartbeats,
    },
  }

  M.send(message, function(response, err)
    if err then
      callback(false, err)
    else
      callback(true, nil)
    end
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
