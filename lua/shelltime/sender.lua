-- Heartbeat sender for shelltime

local config = require('shelltime.config')
local socket = require('shelltime.socket')
local heartbeat = require('shelltime.heartbeat')
local version = require('shelltime.version')
local offline = require('shelltime.offline')

local M = {}

-- Flush timer
local flush_timer = nil

-- Autocmd group for the exit flush
local augroup = nil

-- How long Neovim may wait on exit for pending heartbeats to be sent
local EXIT_FLUSH_TIMEOUT = 1500

-- Heartbeats per socket message, so a backlog never goes out as one huge request
local MAX_PER_MESSAGE = 500

-- Connection status
local is_connected = false

-- Sends in progress by id: their heartbeats and how many the daemon took,
-- until it is known what became of the rest
local outstanding = {}
local next_send_id = 0

-- Whether the daemon last dropped heartbeats because code tracking is off
local tracking_disabled = false
local disabled_notice_shown = false

local function notify_tracking_disabled()
  if disabled_notice_shown then
    return
  end
  disabled_notice_shown = true
  vim.notify(
    '[shelltime] The daemon is not recording editor activity because code tracking is off. '
      .. 'Set codeTracking.enabled to true in ~/.shelltime/config.yaml (an older daemon also needs '
      .. '`shelltime daemon reinstall`). Your activity is kept until then.',
    vim.log.levels.WARN
  )
end

--- Send pending heartbeats to daemon, at most MAX_PER_MESSAGE per message
---@param callback function|nil Optional callback(success, error)
local function send_heartbeats(callback)
  local heartbeats = heartbeat.flush()

  if #heartbeats == 0 then
    if callback then
      callback(true, nil)
    end
    return
  end

  next_send_id = next_send_id + 1
  local id = next_send_id
  local send = { heartbeats = heartbeats, delivered = 0 }
  outstanding[id] = send

  local function finish(sent, status, err)
    -- exit_flush gives up on a send that takes too long and saves the rest itself
    local abandoned = outstanding[id] == nil
    outstanding[id] = nil
    is_connected = status ~= 'failed'
    tracking_disabled = status == 'disabled'

    if sent < #heartbeats and not abandoned then
      -- Keep them for the next flush instead of dropping them
      heartbeat.requeue(vim.list_slice(heartbeats, sent + 1))
    end
    if tracking_disabled then
      notify_tracking_disabled()
    end

    if config.get('debug') then
      if status == 'ok' then
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
      callback(status == 'ok', err)
    end
  end

  local function send_from(sent)
    if sent >= #heartbeats then
      finish(sent, 'ok', nil)
      return
    end
    local chunk = vim.list_slice(heartbeats, sent + 1, sent + MAX_PER_MESSAGE)
    socket.send_heartbeats(chunk, function(status, err)
      if status == 'ok' then
        send.delivered = sent + #chunk
        if outstanding[id] == nil then
          -- exit_flush stopped waiting and saved the rest to the offline file
          finish(sent + #chunk, status, err)
          return
        end
        send_from(sent + #chunk)
      else
        finish(sent, status, err)
      end
    end)
  end

  send_from(0)
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
      M.exit_flush()
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

--- Flush pending heartbeats and block until every send in progress, this one
--- and any started earlier, has finished or the timeout passed
---@param timeout number Maximum wait in milliseconds
---@return boolean True if they all finished within the timeout
function M.flush_sync(timeout)
  send_heartbeats()
  return vim.wait(timeout, function()
    return next(outstanding) == nil
  end, 10)
end

--- Send what is pending before Neovim exits, and leave what doesn't go out
--- (no daemon, or no answer in time) for the daemon to send later: what the
--- sends still in progress have not delivered, and what is still queued
---@param timeout number|nil Maximum wait in milliseconds (1.5 s by default)
function M.exit_flush(timeout)
  M.flush_sync(timeout or EXIT_FLUSH_TIMEOUT)

  local ids = vim.tbl_keys(outstanding)
  table.sort(ids)
  local unsent = {}
  for _, id in ipairs(ids) do
    local send = outstanding[id]
    outstanding[id] = nil
    vim.list_extend(unsent, send.heartbeats, send.delivered + 1)
  end
  vim.list_extend(unsent, heartbeat.flush())
  offline.save(unsent)
end

--- Get connection status
---@return boolean
function M.is_connected()
  return is_connected
end

--- Whether the daemon dropped the last heartbeats because code tracking is off
---@return boolean
function M.is_tracking_disabled()
  return tracking_disabled
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
