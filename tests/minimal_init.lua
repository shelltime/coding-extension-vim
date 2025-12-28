-- Minimal init for running tests
-- This file is used by the test runner to bootstrap the test environment

-- Add the plugin to runtimepath
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.rtp:prepend(plugin_dir)

-- Add tests directory to package path for helpers
package.path = plugin_dir .. '/tests/?.lua;' .. package.path
package.path = plugin_dir .. '/tests/?/init.lua;' .. package.path

-- Disable swap files for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
