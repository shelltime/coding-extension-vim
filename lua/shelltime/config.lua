-- Configuration loading for shelltime

local yaml = require('shelltime.utils.yaml')
local toml = require('shelltime.utils.toml')

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

-- Without a `config` option the plugin reads what the ShellTime CLI reads
-- (cli/model/config.go): the first of these base files that exists, with the
-- first local file merged over it
local config_dir = '~/.shelltime'
local base_files = { 'config.yaml', 'config.yml', 'config.toml' }
local local_files = { 'config.local.yaml', 'config.local.yml', 'config.local.toml' }

-- How often get_config() looks at the files again; it runs on every cursor move
local RECHECK_INTERVAL_MS = 5000

-- Cached config
local cached_config = nil
local cached_signature = nil
local last_check = nil
local config_path = nil
local test_mode = false

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
    return stat.mtime.sec * 1e9 + stat.mtime.nsec
  end
  return nil
end

--- First of the given names in the config directory that exists
---@param names string[] File names
---@return string|nil Expanded path
local function first_existing(names)
  local dir = expand_path(config_dir)
  for _, name in ipairs(names) do
    local path = dir .. '/' .. name
    if vim.loop.fs_stat(path) then
      return path
    end
  end
  return nil
end

--- The files to read, base first
---@return string[] Expanded paths
local function config_files()
  if config_path then
    return { expand_path(config_path) }
  end
  local base = first_existing(base_files)
  if not base then
    return {}
  end
  local local_file = first_existing(local_files)
  return local_file and { base, local_file } or { base }
end

--- Paths and modification times of the files, to tell when they change
---@param files string[] Expanded paths
---@return string
local function signature_of(files)
  local parts = {}
  for _, path in ipairs(files) do
    table.insert(parts, path .. ':' .. tostring(get_mtime(path)))
  end
  return table.concat(parts, '|')
end

--- Load configuration from a YAML or TOML file
---@param path string Expanded config file path
---@return table Configuration table
local function load_config_file(path)
  local parser = path:match('%.toml$') and toml or yaml
  local file_config, err = parser.load_file(path)

  if err then
    if defaults.debug then
      vim.notify('[shelltime] ' .. err, vim.log.levels.WARN)
    end
    return {}
  end

  return file_config or {}
end

--- Merge a local override file over the base file, as the CLI's mergeConfig:
--- set values replace the base's, empty strings don't, and codeTracking merges
--- field by field (a local file that only sets its token keeps tracking on)
---@param base table Base file config
---@param override table Local file config
---@return table Merged file config
local function merge_file_configs(base, override)
  local merged = vim.tbl_extend('force', {}, base)
  for key, value in pairs(override) do
    if key == 'codeTracking' and type(value) == 'table' and type(merged[key]) == 'table' then
      merged[key] = merge_file_configs(merged[key], value)
    elseif value ~= '' then
      merged[key] = value
    end
  end
  return merged
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

  -- API and web endpoints for version check (TOML spells them APIEndpoint and WebEndpoint)
  local api_endpoint = file_config.apiEndpoint or file_config.APIEndpoint
  if api_endpoint then
    config.api_endpoint = api_endpoint
  end

  local web_endpoint = file_config.webEndpoint or file_config.WebEndpoint
  if web_endpoint then
    config.web_endpoint = web_endpoint
  end

  return config
end

--- Initialize configuration
---@param opts table|nil Setup options
function M.setup(opts)
  opts = opts or {}
  config_path = opts.config

  -- Force reload
  cached_config = nil
  cached_signature = nil
  last_check = nil
  test_mode = false
end

--- Get merged configuration
---@return table Configuration
function M.get_config()
  -- In test mode, always return cached config
  if test_mode and cached_config then
    return cached_config
  end

  -- Look at the files at most every few seconds
  local now = vim.loop.hrtime() / 1e6
  if cached_config and last_check and now - last_check < RECHECK_INTERVAL_MS then
    return cached_config
  end
  last_check = now

  local files = config_files()
  local signature = signature_of(files)
  if cached_config and signature == cached_signature then
    return cached_config
  end

  -- Load and cache
  local file_config = {}
  for _, path in ipairs(files) do
    file_config = merge_file_configs(file_config, load_config_file(path))
  end
  cached_config = merge_config(file_config)
  cached_signature = signature

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

--- Get config file path: the one passed to setup(), else the base file the
--- CLI's discovery picks (config.yaml when there is none yet)
---@return string Config path
function M.get_config_path()
  if config_path then
    return config_path
  end
  for _, name in ipairs(base_files) do
    if vim.loop.fs_stat(expand_path(config_dir .. '/' .. name)) then
      return config_dir .. '/' .. name
    end
  end
  return default_config_path
end

--- Set config values directly (for testing only)
---@param config_values table Config values to set
function M._set_for_testing(config_values)
  cached_config = vim.tbl_deep_extend('force', {}, defaults, config_values)
  test_mode = true
end

return M
