-- System information utilities for shelltime

local M = {}

--- Get machine hostname
---@return string Hostname
function M.get_hostname()
  local uv = vim.loop or vim.uv
  return uv.os_gethostname() or 'unknown'
end

--- Get OS name (macOS, Linux, Windows)
---@return string OS name
function M.get_os_name()
  local uv = vim.loop or vim.uv
  local uname = uv.os_uname()
  local sysname = uname.sysname

  if sysname == 'Darwin' then
    return 'macOS'
  elseif sysname == 'Linux' then
    return 'Linux'
  elseif sysname:match('Windows') or sysname == 'Windows_NT' then
    return 'Windows'
  else
    return sysname
  end
end

--- Get OS version
---@return string OS version/release
function M.get_os_version()
  local uv = vim.loop or vim.uv
  local uname = uv.os_uname()
  return uname.release or ''
end

--- Get Neovim version string
---@return string Neovim version
function M.get_editor_version()
  local v = vim.version()
  return string.format('%d.%d.%d', v.major, v.minor, v.patch)
end

-- Project root markers
local root_markers = {
  '.git',
  'package.json',
  'Cargo.toml',
  'go.mod',
  'pyproject.toml',
  'setup.py',
  'Makefile',
  'CMakeLists.txt',
  '.project',
  '.root',
}

--- Find project root by searching for marker files
---@param file_path string Starting file path
---@return string Project root path
function M.get_project_root(file_path)
  local path = vim.fn.fnamemodify(file_path, ':p:h')

  while path and path ~= '/' and path ~= '' do
    for _, marker in ipairs(root_markers) do
      local marker_path = path .. '/' .. marker
      if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
        return path
      end
    end
    local parent = vim.fn.fnamemodify(path, ':h')
    if parent == path then
      break
    end
    path = parent
  end

  -- Fallback to file's directory
  return vim.fn.fnamemodify(file_path, ':p:h')
end

--- Get project name from root path (last 2 folder layers)
---@param project_root string Project root path
---@return string Project name
function M.get_project_name(project_root)
  local tail = vim.fn.fnamemodify(project_root, ':t')
  local parent = vim.fn.fnamemodify(project_root, ':h:t')
  if parent and parent ~= '' and parent ~= '/' then
    return parent .. '/' .. tail
  end
  return tail
end

-- Whether the math.random fallback has been seeded
local seeded = false

--- Get 16 random bytes, from the OS when possible
---@return number[] Byte values (0-255)
local function random_bytes()
  local uv = vim.uv or vim.loop
  local ok, bytes = pcall(uv.random, 16)
  if ok and type(bytes) == 'string' and #bytes == 16 then
    return { bytes:byte(1, 16) }
  end

  -- Seed once: reseeding on every call from the clock repeats sequences
  -- across calls and Neovim instances, and heartbeat ids must be unique.
  if not seeded then
    math.randomseed(uv.hrtime() + uv.os_getpid())
    seeded = true
  end
  local result = {}
  for i = 1, 16 do
    result[i] = math.random(0, 255)
  end
  return result
end

--- Generate UUID v4
---@return string UUID string
function M.uuid()
  local b = random_bytes()
  b[7] = (b[7] % 16) + 0x40 -- version 4
  b[9] = (b[9] % 64) + 0x80 -- RFC 4122 variant
  return string.format(
    '%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x',
    unpack(b)
  )
end

--- Get current Unix timestamp in seconds
---@return number Unix timestamp
function M.get_timestamp()
  return os.time()
end

return M
