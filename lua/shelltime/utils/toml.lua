-- Minimal TOML parser for shelltime config
-- Supports: key = value pairs and [table] headers, with strings, numbers and booleans

local M = {}

local function trim(s)
  return s:match('^%s*(.-)%s*$')
end

local function parse_value(value)
  value = trim(value)

  -- Quoted string; a # inside it is not a comment
  local quoted = value:match('^"(.-)"') or value:match("^'(.-)'")
  if quoted then
    return quoted
  end

  -- Drop a trailing comment
  value = trim(value:gsub('%s+#.*$', ''))

  if value == 'true' then
    return true
  elseif value == 'false' then
    return false
  end

  local num = tonumber(value)
  if num then
    return num
  end

  return value
end

--- Parse TOML string into Lua table
---@param content string TOML content
---@return table Parsed table
function M.parse(content)
  local result = {}
  local current = result

  for line in content:gmatch('[^\r\n]+') do
    local trimmed = trim(line)
    if trimmed ~= '' and not trimmed:match('^#') then
      local table_name = trimmed:match('^%[%s*([%w_%.%-]+)%s*%]')
      if table_name then
        -- [a.b] nests a table in a
        current = result
        for part in table_name:gmatch('[^%.]+') do
          current[part] = current[part] or {}
          current = current[part]
        end
      else
        local key, value = trimmed:match('^([%w_%-]+)%s*=%s*(.-)$')
        if key then
          current[key] = parse_value(value)
        end
      end
    end
  end

  return result
end

--- Load and parse TOML file
---@param path string File path
---@return table|nil Parsed table or nil on error
---@return string|nil Error message
function M.load_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil, 'Cannot open file: ' .. path
  end

  local content = file:read('*a')
  file:close()

  local ok, result = pcall(M.parse, content)
  if not ok then
    return nil, 'Parse error: ' .. tostring(result)
  end

  return result, nil
end

return M
