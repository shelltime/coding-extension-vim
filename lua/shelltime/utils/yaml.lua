-- Minimal YAML parser for shelltime config
-- Supports: key-value pairs, nested objects, strings, numbers, booleans

local M = {}

local function trim(s)
  return s:match('^%s*(.-)%s*$')
end

local function parse_value(value)
  value = trim(value)

  -- Remove quotes if present
  if value:match('^".*"$') or value:match("^'.*'$") then
    return value:sub(2, -2)
  end

  -- Boolean
  if value == 'true' then
    return true
  elseif value == 'false' then
    return false
  end

  -- Null
  if value == 'null' or value == '~' or value == '' then
    return nil
  end

  -- Number
  local num = tonumber(value)
  if num then
    return num
  end

  -- String
  return value
end

local function get_indent(line)
  local spaces = line:match('^(%s*)')
  return #spaces
end

--- Parse YAML string into Lua table
---@param content string YAML content
---@return table Parsed table
function M.parse(content)
  local result = {}
  local stack = { { obj = result, indent = -1 } }

  for line in content:gmatch('[^\r\n]+') do
    -- Skip empty lines and comments
    if not line:match('^%s*$') and not line:match('^%s*#') then
      local indent = get_indent(line)
      local trimmed = trim(line)

      -- Pop stack until we find parent with smaller indent
      while #stack > 1 and stack[#stack].indent >= indent do
        table.remove(stack)
      end

      local current = stack[#stack].obj

      -- Check for key-value pair
      local key, value = trimmed:match('^([%w_]+):%s*(.*)$')

      if key then
        if value == '' then
          -- Nested object
          current[key] = {}
          table.insert(stack, { obj = current[key], indent = indent })
        else
          -- Simple value
          current[key] = parse_value(value)
        end
      end
    end
  end

  return result
end

--- Load and parse YAML file
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
