-- Git utilities for shelltime

local M = {}

--- Get current git branch for a file
---@param file_path string File path
---@return string Branch name or empty string
function M.get_branch(file_path)
  local dir = vim.fn.fnamemodify(file_path, ':p:h')

  -- Check if directory exists
  if vim.fn.isdirectory(dir) ~= 1 then
    return ''
  end

  local result = vim.fn.systemlist({
    'git',
    '-C',
    dir,
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  })

  -- Check for errors
  if vim.v.shell_error ~= 0 then
    return ''
  end

  if result and #result > 0 then
    return vim.trim(result[1])
  end

  return ''
end

return M
