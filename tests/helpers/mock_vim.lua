-- vim.* API mocking utilities
local stub = require('luassert.stub')

local M = {}

--- Stub specific vim.api function
---@param func_name string Function name (e.g., 'nvim_buf_get_name')
---@param return_value any Value to return
---@return table stub
function M.stub_api(func_name, return_value)
  local s = stub(vim.api, func_name)
  if return_value ~= nil then
    s.returns(return_value)
  end
  return s
end

--- Setup common mocks for buffer-related tests
---@param opts table|nil Options
---@return table mocks Table of mock objects to revert later
function M.setup_buffer_mocks(opts)
  opts = vim.tbl_extend('force', {
    bufnr = 1,
    name = '/project/src/file.lua',
    filetype = 'lua',
    buftype = '',
    lines = 100,
    cursor = { 50, 10 },
    valid = true,
  }, opts or {})

  local mocks = {}

  mocks.nvim_buf_is_valid = stub(vim.api, 'nvim_buf_is_valid')
  mocks.nvim_buf_is_valid.returns(opts.valid)

  mocks.nvim_buf_get_name = stub(vim.api, 'nvim_buf_get_name')
  mocks.nvim_buf_get_name.returns(opts.name)

  mocks.nvim_get_current_buf = stub(vim.api, 'nvim_get_current_buf')
  mocks.nvim_get_current_buf.returns(opts.bufnr)

  mocks.nvim_buf_line_count = stub(vim.api, 'nvim_buf_line_count')
  mocks.nvim_buf_line_count.returns(opts.lines)

  mocks.nvim_win_get_cursor = stub(vim.api, 'nvim_win_get_cursor')
  mocks.nvim_win_get_cursor.returns(opts.cursor)

  return mocks
end

--- Revert all mocks in a table
---@param mocks table Table of mock/stub objects
function M.revert_all(mocks)
  for _, m in pairs(mocks) do
    if type(m) == 'table' and m.revert then
      m:revert()
    end
  end
end

return M
