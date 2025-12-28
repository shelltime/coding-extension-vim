-- Test helpers for shelltime.nvim
local M = {}

--- Get the tests directory path
---@return string
function M.get_tests_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(source, ':h:h')
end

--- Get fixture file path
---@param name string Fixture filename
---@return string
function M.fixture_path(name)
  return M.get_tests_dir() .. '/fixtures/' .. name
end

--- Get project root directory
---@return string
function M.get_project_dir()
  return vim.fn.fnamemodify(M.get_tests_dir(), ':h')
end

return M
