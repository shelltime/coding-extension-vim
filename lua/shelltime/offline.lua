-- Heartbeats left for the daemon to send

local M = {}

-- Heartbeats per line, as the sender batches them
local MAX_PER_LINE = 500

-- Don't grow the file without bound when no daemon ever reads it
local MAX_FILE_BYTES = 50 * 1024 * 1024

--- The daemon's file for heartbeats it could not send (cli/model/db.go
--- HEARTBEAT_LOG_FILE): one {"heartbeats": [...]} payload per line, resent when
--- the daemon starts and every 30 minutes. Heartbeat ids make a resend of one
--- that did arrive harmless.
---@return string Path
function M.default_path()
  local home = os.getenv('HOME') or os.getenv('USERPROFILE') or ''
  return home .. '/.shelltime/coding-heartbeat.data.log'
end

--- Leave heartbeats that could not be delivered before Neovim exits for the
--- daemon to send once it runs again
---@param heartbeats table[] Heartbeats
---@param path string|nil File, the daemon's by default
---@return boolean Whether they were written
function M.save(heartbeats, path)
  if #heartbeats == 0 then
    return true
  end
  path = path or M.default_path()

  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(path)
  if stat and stat.size > MAX_FILE_BYTES then
    return false
  end
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')

  local lines = {}
  for i = 1, #heartbeats, MAX_PER_LINE do
    local ok, line = pcall(vim.json.encode, { heartbeats = vim.list_slice(heartbeats, i, i + MAX_PER_LINE - 1) })
    if not ok then
      return false
    end
    table.insert(lines, line)
  end

  local file = io.open(path, 'a')
  if not file then
    return false
  end
  file:write(table.concat(lines, '\n') .. '\n')
  file:close()
  return true
end

return M
