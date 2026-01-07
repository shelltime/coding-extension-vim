-- Configuration loading for shelltime

local yaml = require('shelltime.utils.yaml')

local M = {}

-- Default configuration values
local defaults = {
  socket_path = '/tmp/shelltime.sock',
  enabled = true,
  heartbeat_interval = 120000, -- 2 minutes in ms
  debounce_interval = 30000,   -- 30 seconds in ms
  debug = false,
  api_endpoint = nil,          -- API endpoint for version check
  web_endpoint = nil,          -- Web endpoint for update command
}

-- Default config file path
local default_config_path = '~/.shelltime/config.yaml'

-- Cached config
local cached_config = nil
local cached_mtime = nil
local config_path = nil

--- Expand tilde in path
---@param path string Path with possible tilde
---@return string Expanded path
local function expand_path(path)
  if path:sub(1, 1) == '~' then
    local home = os.getenv('HOME') or os.getenv('USERPROFILE') or ''
    return home .. path:sub(2)
  end
  return path
end

--- Get file modification time
---@param path string File path
---@return number|nil Modification time or nil
local function get_mtime(path)
  local stat = vim.loop.fs_stat(path)
  if stat then
    return stat.mtime.sec
  end
  return nil
end

--- Load configuration from YAML file
---@param path string Config file path
---@return table Configuration table
local function load_config_file(path)
  local expanded = expand_path(path)
  local file_config, err = yaml.load_file(expanded)

  if err then
    if defaults.debug then
      vim.notify('[shelltime] ' .. err, vim.log.levels.WARN)
    end
    return {}
  end

  return file_config or {}
end

--- Merge file config with defaults
---@param file_config table Config from file
---@return table Merged config
local function merge_config(file_config)
  local config = vim.tbl_deep_extend('force', {}, defaults)

  -- Map YAML keys to internal config keys
  if file_config.socketPath then
    config.socket_path = file_config.socketPath
  end

  if file_config.codeTracking then
    if file_config.codeTracking.enabled ~= nil then
      config.enabled = file_config.codeTracking.enabled
    end
  end

  if file_config.debug ~= nil then
    config.debug = file_config.debug
  end

  if file_config.heartbeatInterval then
    config.heartbeat_interval = file_config.heartbeatInterval
  end

  if file_config.debounceInterval then
    config.debounce_interval = file_config.debounceInterval
  end

  -- API and web endpoints for version check
  if file_config.apiEndpoint then
    config.api_endpoint = file_config.apiEndpoint
  end

  if file_config.webEndpoint then
    config.web_endpoint = file_config.webEndpoint
  end

  return config
end

--- Initialize configuration
---@param opts table|nil Setup options
function M.setup(opts)
  opts = opts or {}
  config_path = opts.config or default_config_path

  -- Force reload
  cached_config = nil
  cached_mtime = nil
end

--- Get merged configuration
---@return table Configuration
function M.get_config()
  local path = expand_path(config_path or default_config_path)
  local mtime = get_mtime(path)

  -- Use cache if valid
  if cached_config and mtime and mtime == cached_mtime then
    return cached_config
  end

  -- Load and cache
  local file_config = load_config_file(config_path or default_config_path)
  cached_config = merge_config(file_config)
  cached_mtime = mtime

  return cached_config
end

--- Get a specific config value
---@param key string Config key
---@return any Config value
function M.get(key)
  local config = M.get_config()
  return config[key]
end

--- Check if tracking is enabled
---@return boolean
function M.is_enabled()
  return M.get('enabled') == true
end

--- Get config file path
---@return string Config path
function M.get_config_path()
  return config_path or default_config_path
end

return M
