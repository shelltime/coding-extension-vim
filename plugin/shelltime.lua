-- shelltime.nvim plugin loader
-- Auto-load and command registration

-- Prevent double loading
if vim.g.loaded_shelltime then
  return
end
vim.g.loaded_shelltime = true

-- Check Neovim version
if vim.fn.has('nvim-0.10') ~= 1 then
  vim.notify('[shelltime] Requires Neovim 0.10.0 or later', vim.log.levels.ERROR)
  return
end

-- Register commands
vim.api.nvim_create_user_command('ShellTimeStatus', function()
  require('shelltime').status()
end, {
  desc = 'Show ShellTime daemon connection status',
})

vim.api.nvim_create_user_command('ShellTimeFlush', function()
  require('shelltime').flush()
end, {
  desc = 'Manually flush pending heartbeats',
})

vim.api.nvim_create_user_command('ShellTimeEnable', function()
  require('shelltime').enable()
  vim.notify('[shelltime] Tracking enabled', vim.log.levels.INFO)
end, {
  desc = 'Enable ShellTime tracking',
})

vim.api.nvim_create_user_command('ShellTimeDisable', function()
  require('shelltime').disable()
  vim.notify('[shelltime] Tracking disabled', vim.log.levels.INFO)
end, {
  desc = 'Disable ShellTime tracking',
})
