-- Coverage init for running tests with luacov
-- This file wraps minimal_init.lua and adds luacov support

-- Initialize luacov BEFORE loading any other modules
local ok, luacov = pcall(require, 'luacov')
if not ok then
  print('Warning: luacov not found, running tests without coverage')
end

-- Load the regular minimal init
local script_path = debug.getinfo(1, 'S').source:sub(2)
local tests_dir = vim.fn.fnamemodify(script_path, ':h')
dofile(tests_dir .. '/minimal_init.lua')

-- Save coverage stats on exit
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    if ok and luacov then
      local runner = require('luacov.runner')
      runner.save_stats()
    end
  end,
})
