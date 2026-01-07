-- Version checker for shelltime

local config = require('shelltime.config')

local M = {}

-- Track if warning has been shown this session
local has_shown_warning = false

-- Version check API endpoint path
local VERSION_CHECK_ENDPOINT = '/api/v1/cli/version-check'

--- URL encode a string
---@param str string String to encode
---@return string Encoded string
local function url_encode(str)
  if str then
    str = string.gsub(str, '\n', '\r\n')
    str = string.gsub(str, '([^%w _%%%-%.~])', function(c)
      return string.format('%%%02X', string.byte(c))
    end)
    str = string.gsub(str, ' ', '+')
  end
  return str
end

--- Parse JSON response (minimal parser for version check response)
---@param json_str string JSON string
---@return table|nil Parsed table or nil on error
local function parse_json(json_str)
  -- Simple JSON parser for { "isLatest": bool, "latestVersion": "...", "version": "..." }
  local is_latest = json_str:match('"isLatest"%s*:%s*(true)')
  local latest_version = json_str:match('"latestVersion"%s*:%s*"([^"]+)"')
  local version = json_str:match('"version"%s*:%s*"([^"]+)"')

  if latest_version and version then
    return {
      isLatest = is_latest ~= nil,
      latestVersion = latest_version,
      version = version,
    }
  end
  return nil
end

--- Check CLI version against server
---@param daemon_version string Current daemon version
---@param callback function|nil Optional callback(result, error)
function M.check_version(daemon_version, callback)
  local api_endpoint = config.get('api_endpoint')
  local web_endpoint = config.get('web_endpoint')

  if not api_endpoint or not web_endpoint then
    if config.get('debug') then
      vim.notify('[shelltime] No API/web endpoint configured, skipping version check', vim.log.levels.DEBUG)
    end
    if callback then
      callback(nil, 'No endpoint configured')
    end
    return
  end

  if has_shown_warning then
    if config.get('debug') then
      vim.notify('[shelltime] Version warning already shown this session', vim.log.levels.DEBUG)
    end
    if callback then
      callback(nil, 'Already shown')
    end
    return
  end

  local url = api_endpoint .. VERSION_CHECK_ENDPOINT .. '?version=' .. url_encode(daemon_version)

  if config.get('debug') then
    vim.notify('[shelltime] Checking version at: ' .. url, vim.log.levels.DEBUG)
  end

  -- Use curl asynchronously via vim.fn.jobstart
  local stdout_data = {}

  vim.fn.jobstart({ 'curl', '-sSL', '-m', '5', '-H', 'Accept: application/json', url }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(stdout_data, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          if config.get('debug') then
            vim.notify('[shelltime] Version check failed with exit code: ' .. exit_code, vim.log.levels.DEBUG)
          end
          if callback then
            callback(nil, 'curl failed')
          end
          return
        end

        local response = table.concat(stdout_data, '')
        local result = parse_json(response)

        if result then
          if not result.isLatest then
            has_shown_warning = true
            M.show_update_warning(daemon_version, result.latestVersion, web_endpoint)
          elseif config.get('debug') then
            vim.notify('[shelltime] CLI version ' .. daemon_version .. ' is up to date', vim.log.levels.DEBUG)
          end

          if callback then
            callback(result, nil)
          end
        else
          if config.get('debug') then
            vim.notify('[shelltime] Failed to parse version check response', vim.log.levels.DEBUG)
          end
          if callback then
            callback(nil, 'Parse error')
          end
        end
      end)
    end,
  })
end

--- Show update warning notification
---@param current_version string Current version
---@param latest_version string Latest available version
---@param web_endpoint string Web endpoint for update command
function M.show_update_warning(current_version, latest_version, web_endpoint)
  local update_command = 'curl -sSL ' .. web_endpoint .. '/i | bash'
  local message = string.format(
    '[shelltime] CLI update available: %s -> %s\n\nRun: %s',
    current_version,
    latest_version,
    update_command
  )

  vim.notify(message, vim.log.levels.WARN)

  -- Also copy to clipboard if available
  if vim.fn.has('clipboard') == 1 then
    vim.fn.setreg('+', update_command)
    vim.notify('[shelltime] Update command copied to clipboard', vim.log.levels.INFO)
  end
end

return M
