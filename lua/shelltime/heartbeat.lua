-- Heartbeat collection for shelltime

local config = require('shelltime.config')
local system = require('shelltime.utils.system')
local git = require('shelltime.utils.git')
local lang = require('shelltime.utils.language')

local M = {}

-- Plugin version
local PLUGIN_VERSION = '0.0.5' -- x-release-please-version

-- Pending heartbeats queue
local pending_heartbeats = {}

-- Upper bound for the queue while the daemon is unreachable
local MAX_PENDING = 5000

-- Last heartbeat time per file (for debouncing)
local last_heartbeat_time = {}

-- The write heartbeat of the latest save inside its file's debounce window,
-- per file: sent ahead of the file's next heartbeat, or with the next flush
local pending_writes = {}

-- Each buffer's changedtick right after it was read from disk: a text change
-- at that tick is the file loaded or reloaded, not typing
local read_ticks = {}

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
  -- Only when nvim-dap is already loaded: requiring it would load a lazy-loaded plugin
  local dap = package.loaded['dap']
  if type(dap) == 'table' and type(dap.session) == 'function' then
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

--- Cursor of a buffer: from a window showing it, else where it was last left.
--- The current window isn't always it: :wa and :bufdo write other buffers, which
--- Neovim shows in a temporary autocmd window with the cursor on line 1.
---@param bufnr number Buffer number
---@return table|nil { line (1-indexed), column (0-indexed) }
local function get_cursor(bufnr)
  if vim.api.nvim_get_current_buf() == bufnr and vim.fn.win_gettype() ~= 'autocmd' then
    return vim.api.nvim_win_get_cursor(0)
  end
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.fn.win_gettype(win) ~= 'autocmd' then
      return vim.api.nvim_win_get_cursor(win)
    end
  end
  local ok, mark = pcall(vim.api.nvim_buf_get_mark, bufnr, '"')
  if ok and mark[1] > 0 then
    return mark
  end
  return nil
end

--- Create heartbeat data for a buffer
---@param bufnr number Buffer number
---@param is_write boolean Whether this is a write event
---@param cursor table|nil Cursor from get_cursor
---@return table|nil Heartbeat data or nil
local function create_heartbeat(bufnr, is_write, cursor)
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
    lineNumber = cursor and cursor[1],       -- Already 1-indexed
    cursorPosition = cursor and cursor[2],   -- 0-indexed column
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
---@param bufnr number Buffer the event is for
---@param is_write boolean Whether this is a write event
---@param is_navigation boolean Whether this is a navigation event (BufEnter, cursor moves)
local function on_event(bufnr, is_write, is_navigation)
  if not config.is_enabled() then
    return
  end

  if not is_valid_buffer(bufnr) then
    return
  end

  -- A reload of the file from disk (:checktime after a git checkout, a
  -- formatter or an AI agent rewrote it) changes the text but isn't typing.
  -- 'modified' can't tell it from an undo back to the saved state.
  if not is_write and not is_navigation
    and read_ticks[bufnr] == vim.api.nvim_buf_get_changedtick(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)

  -- Get cursor position for duplicate detection
  local cursor = get_cursor(bufnr)
  local line_number = cursor and cursor[1]
  local cursor_position = cursor and cursor[2]

  -- Skip repeated navigation events (same file and cursor position).
  -- Edits always count, even when the cursor stays in place (x, dd).
  if is_navigation and is_duplicate_activity(file_path, line_number, cursor_position, is_write) then
    return
  end

  -- Update last activity state immediately after duplicate check
  -- This ensures we track the latest position even if debounce blocks sending
  update_last_activity(file_path, line_number, cursor_position)

  -- Saves count once per debounce window too: an auto-save plugin writes after
  -- every change. A save inside the window is held as the file's pending write
  -- (at its own time and cursor, replacing an earlier one), so the last save
  -- before :wq is still sent.
  if not should_send_heartbeat(file_path, false) then
    if is_write then
      pending_writes[file_path] = create_heartbeat(bufnr, true, cursor)
    end
    return
  end

  local heartbeat = create_heartbeat(bufnr, is_write, cursor)
  if heartbeat then
    if pending_writes[file_path] then
      add_heartbeat(pending_writes[file_path])
      pending_writes[file_path] = nil
    end
    add_heartbeat(heartbeat)
  end
end

--- Start collecting heartbeats
function M.start()
  if augroup then
    return -- Already started
  end

  augroup = vim.api.nvim_create_augroup('ShellTimeHeartbeat', { clear = true })

  -- File opened. :bufdo, :argdo, :cfdo and session restore enter every buffer
  -- in turn; only the one still current once the command is done is the user's.
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function(args)
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == args.buf then
          on_event(args.buf, false, true)
        end
      end)
    end,
  })

  -- File read from disk, when opened or reloaded after it changed outside
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'FileChangedShellPost' }, {
    group = augroup,
    callback = function(args)
      read_ticks[args.buf] = vim.api.nvim_buf_get_changedtick(args.buf)
    end,
  })

  -- Text changed
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    callback = function(args)
      on_event(args.buf, false, false)
    end,
  })

  -- File saved: args.buf is the buffer written, which :wa and :bufdo w make
  -- different from the one being edited
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

--- Get and clear pending heartbeats, the saves held back by the debounce included
---@return table[] Pending heartbeats
function M.flush()
  local heartbeats = pending_heartbeats
  pending_heartbeats = {}
  for _, write in pairs(pending_writes) do
    table.insert(heartbeats, write)
  end
  pending_writes = {}
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
  return #pending_heartbeats + vim.tbl_count(pending_writes)
end

--- Clear debounce cache
function M.clear_cache()
  last_heartbeat_time = {}
  pending_writes = {}
  last_activity = {
    file_path = nil,
    line_number = nil,
    cursor_position = nil,
  }
end

return M
