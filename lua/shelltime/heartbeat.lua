-- Heartbeat collection for shelltime

local config = require('shelltime.config')
local system = require('shelltime.utils.system')
local git = require('shelltime.utils.git')
local lang = require('shelltime.utils.language')

local M = {}

-- Plugin version
local PLUGIN_VERSION = '0.0.2' -- x-release-please-version

-- Pending heartbeats queue
local pending_heartbeats = {}

-- Last heartbeat time per file (for debouncing)
local last_heartbeat_time = {}

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
  if file_path:match('/.git/') then
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

--- Create heartbeat data for current buffer
---@param bufnr number Buffer number
---@param is_write boolean Whether this is a write event
---@return table|nil Heartbeat data or nil
local function create_heartbeat(bufnr, is_write)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == '' then
    return nil
  end

  local project_root = system.get_project_root(file_path)
  local cursor = vim.api.nvim_win_get_cursor(0)

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
    lineNumber = cursor[1],       -- Already 1-indexed
    cursorPosition = cursor[2],   -- 0-indexed column
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

--- Add heartbeat to pending queue
---@param heartbeat table Heartbeat data
local function add_heartbeat(heartbeat)
  table.insert(pending_heartbeats, heartbeat)

  if config.get('debug') then
    vim.notify(
      string.format('[shelltime] Heartbeat: %s (%s)', heartbeat.entity, heartbeat.language),
      vim.log.levels.DEBUG
    )
  end
end

--- Handle editor event
---@param is_write boolean Whether this is a write event
local function on_event(is_write)
  if not config.is_enabled() then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  if not is_valid_buffer(bufnr) then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if not should_send_heartbeat(file_path, is_write) then
    return
  end

  local heartbeat = create_heartbeat(bufnr, is_write)
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
    callback = function()
      on_event(false)
    end,
  })

  -- Text changed
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    callback = function()
      on_event(false)
    end,
  })

  -- File saved
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    callback = function()
      on_event(true)
    end,
  })

  -- Cursor moved
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    callback = function()
      on_event(false)
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

--- Get pending heartbeat count
---@return number Count
function M.get_pending_count()
  return #pending_heartbeats
end

--- Clear debounce cache
function M.clear_cache()
  last_heartbeat_time = {}
end

return M
