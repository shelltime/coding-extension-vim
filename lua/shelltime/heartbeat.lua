-- Heartbeat collection for shelltime

local config = require('shelltime.config')
local system = require('shelltime.utils.system')
local git = require('shelltime.utils.git')
local lang = require('shelltime.utils.language')

local M = {}

-- Plugin version
local PLUGIN_VERSION = '0.0.4' -- x-release-please-version

-- Pending heartbeats queue
local pending_heartbeats = {}

-- Upper bound for the queue while the daemon is unreachable
local MAX_PENDING = 5000

-- Last heartbeat time per file (for debouncing)
local last_heartbeat_time = {}

-- Last activity state (for duplicate detection)
local last_activity = {
  file_path = nil,
  line_number = nil,
  cursor_position = nil,
}

-- Autocmd group
local augroup = nil

--- Check if DAP debugger is active
---@return boolean
local function is_debugging()
  local ok, dap = pcall(require, 'dap')
  if ok and dap.session then
    return dap.session() ~= nil
  end
  return false
end

--- Check if buffer is valid for tracking
---@param bufnr number Buffer number
---@return boolean
local function is_valid_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.bo[bufnr].buftype
  if buftype ~= '' then
    return false
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == '' then
    return false
  end

  -- Skip .git directory files
  if file_path:match('[/\\]%.git[/\\]') then
    return false
  end

  -- Only track file:// scheme (regular files)
  if file_path:match('^%w+://') and not file_path:match('^file://') then
    return false
  end

  return true
end

--- Check if heartbeat should be sent (debouncing)
---@param file_path string File path
---@param is_write boolean Whether this is a write event
---@return boolean
local function should_send_heartbeat(file_path, is_write)
  -- Write events always trigger
  if is_write then
    return true
  end

  local now = os.time() * 1000 -- Convert to milliseconds
  local last_time = last_heartbeat_time[file_path] or 0
  local debounce = config.get('debounce_interval')

  if (now - last_time) >= debounce then
    last_heartbeat_time[file_path] = now
    return true
  end

  return false
end

--- Check if activity is a duplicate (same file and cursor position)
---@param file_path string File path
---@param line_number number Line number (1-indexed)
---@param cursor_position number Cursor column (0-indexed)
---@param is_write boolean Whether this is a write event
---@return boolean True if duplicate (should skip)
local function is_duplicate_activity(file_path, line_number, cursor_position, is_write)
  -- Write events are never considered duplicates
  if is_write then
    return false
  end

  -- Check if same as last activity
  if last_activity.file_path == file_path
    and last_activity.line_number == line_number
    and last_activity.cursor_position == cursor_position then
    return true
  end

  return false
end

--- Update last activity state
---@param file_path string File path
---@param line_number number Line number (1-indexed)
---@param cursor_position number Cursor column (0-indexed)
local function update_last_activity(file_path, line_number, cursor_position)
  last_activity.file_path = file_path
  last_activity.line_number = line_number
  last_activity.cursor_position = cursor_position
end

--- Get the cursor of a window showing the buffer
--- Events like BufWritePost (:wa) can fire for buffers other than the current one.
---@param bufnr number Buffer number
---@return number|nil line_number Line number (1-indexed)
---@return number|nil cursor_position Cursor column (0-indexed)
local function get_cursor(bufnr)
  local winid = 0
  if vim.api.nvim_win_get_buf(0) ~= bufnr then
    winid = vim.fn.bufwinid(bufnr)
    if winid == -1 then
      return nil, nil
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(winid)
  return cursor[1], cursor[2]
end

--- Create heartbeat data for a buffer
---@param bufnr number Buffer number
---@param is_write boolean Whether this is a write event
---@param line_number number|nil Line number (1-indexed)
---@param cursor_position number|nil Cursor column (0-indexed)
---@return table|nil Heartbeat data or nil
local function create_heartbeat(bufnr, is_write, line_number, cursor_position)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == '' then
    return nil
  end

  local project_root = system.get_project_root(file_path)

  return {
    heartbeatId = system.uuid(),
    entity = file_path,
    entityType = 'file',
    category = is_debugging() and 'debugging' or 'coding',
    time = system.get_timestamp(),
    project = system.get_project_name(project_root),
    projectRootPath = project_root,
    branch = git.get_branch(file_path),
    language = lang.get_language(vim.bo[bufnr].filetype, file_path),
    lines = vim.api.nvim_buf_line_count(bufnr),
    lineNumber = line_number,
    cursorPosition = cursor_position,
    editor = 'neovim',
    editorVersion = system.get_editor_version(),
    plugin = 'shelltime',
    pluginVersion = PLUGIN_VERSION,
    machine = system.get_hostname(),
    os = system.get_os_name(),
    osVersion = system.get_os_version(),
    isWrite = is_write,
  }
end

--- Drop the oldest heartbeats once the queue exceeds MAX_PENDING
local function trim_queue()
  local overflow = #pending_heartbeats - MAX_PENDING
  if overflow > 0 then
    pending_heartbeats = vim.list_slice(pending_heartbeats, overflow + 1)
  end
end

--- Add heartbeat to pending queue
---@param heartbeat table Heartbeat data
local function add_heartbeat(heartbeat)
  table.insert(pending_heartbeats, heartbeat)
  trim_queue()

  if config.get('debug') then
    vim.notify(
      string.format('[shelltime] Heartbeat: %s (%s)', heartbeat.entity, heartbeat.language),
      vim.log.levels.DEBUG
    )
  end
end

--- Handle editor event
---@param bufnr number Buffer the event fired for
---@param is_write boolean Whether this is a write event
---@param is_navigation boolean Whether this is a navigation event (BufEnter, cursor moves)
local function on_event(bufnr, is_write, is_navigation)
  if not config.is_enabled() then
    return
  end

  if not is_valid_buffer(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)

  -- Get cursor position for duplicate detection
  local line_number, cursor_position = get_cursor(bufnr)

  -- Skip repeated navigation events (same file and cursor position).
  -- Edits always count, even when the cursor stays in place (x, dd).
  if is_navigation and is_duplicate_activity(file_path, line_number, cursor_position, is_write) then
    return
  end

  -- Update last activity state immediately after duplicate check
  -- This ensures we track the latest position even if debounce blocks sending
  update_last_activity(file_path, line_number, cursor_position)

  if not should_send_heartbeat(file_path, is_write) then
    return
  end

  local heartbeat = create_heartbeat(bufnr, is_write, line_number, cursor_position)
  if heartbeat then
    add_heartbeat(heartbeat)
  end
end

--- Start collecting heartbeats
function M.start()
  if augroup then
    return -- Already started
  end

  augroup = vim.api.nvim_create_augroup('ShellTimeHeartbeat', { clear = true })

  -- File opened
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function(args)
      on_event(args.buf, false, true)
    end,
  })

  -- Text changed
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    callback = function(args)
      on_event(args.buf, false, false)
    end,
  })

  -- File saved (args.buf is the written buffer, which for :wa is not the current one)
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    callback = function(args)
      on_event(args.buf, true, false)
    end,
  })

  -- Cursor moved
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    callback = function(args)
      on_event(args.buf, false, true)
    end,
  })
end

--- Stop collecting heartbeats
function M.stop()
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end
end

--- Get and clear pending heartbeats
---@return table[] Pending heartbeats
function M.flush()
  local heartbeats = pending_heartbeats
  pending_heartbeats = {}
  return heartbeats
end

--- Put heartbeats that could not be delivered back at the front of the queue
---@param heartbeats table[] Heartbeats to retry
function M.requeue(heartbeats)
  if #heartbeats == 0 then
    return
  end
  pending_heartbeats = vim.list_extend(vim.list_extend({}, heartbeats), pending_heartbeats)
  trim_queue()
end

--- Get pending heartbeat count
---@return number Count
function M.get_pending_count()
  return #pending_heartbeats
end

--- Clear debounce cache
function M.clear_cache()
  last_heartbeat_time = {}
  last_activity = {
    file_path = nil,
    line_number = nil,
    cursor_position = nil,
  }
end

return M
