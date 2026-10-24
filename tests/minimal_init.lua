-- Minimal init for running tests
-- This file is used by the test runner to bootstrap the test environment

-- Add the plugin to runtimepath
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.rtp:prepend(plugin_dir)

-- Add project root to package path for 'tests.helpers' requires
package.path = plugin_dir .. '/?.lua;' .. package.path
package.path = plugin_dir .. '/?/init.lua;' .. package.path

-- Add tests directory to package path for 'helpers' requires
package.path = plugin_dir .. '/tests/?.lua;' .. package.path
package.path = plugin_dir .. '/tests/?/init.lua;' .. package.path

-- Disable swap files for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Tests must never reach a ShellTime daemon or config on this machine: the
-- daemon sends what it gets to a real account. HOME is a temporary directory,
-- and connections to the default socket go to a path where nothing listens.
-- The test files run in child processes, which find plenary.nvim in the data
-- directory under the real HOME.
vim.env.XDG_DATA_HOME = vim.fn.fnamemodify(vim.fn.stdpath('data'), ':h')
vim.env.HOME = vim.fn.tempname()
vim.fn.mkdir(vim.env.HOME, 'p')

local no_daemon_socket = vim.fn.tempname() .. '-no-daemon.sock'
local uv = vim.loop or vim.uv
local probe = uv.new_pipe(false)
local pipe_methods = getmetatable(probe).__index
probe:close()
local connect = pipe_methods.connect
pipe_methods.connect = function(pipe, path, callback)
  if path == '/tmp/shelltime.sock' then
    path = no_daemon_socket
  end
  return connect(pipe, path, callback)
end
