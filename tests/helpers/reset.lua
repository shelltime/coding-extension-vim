-- Module state reset utilities
local M = {}

--- Reset a module by clearing its cached state
--- This forces require() to reload the module
---@param module_name string Module name to reset
function M.reset_module(module_name)
  package.loaded[module_name] = nil
end

--- Reset all shelltime modules
function M.reset_all()
  local modules = {
    'shelltime',
    'shelltime.config',
    'shelltime.heartbeat',
    'shelltime.sender',
    'shelltime.socket',
    'shelltime.version',
    'shelltime.utils',
    'shelltime.utils.system',
    'shelltime.utils.git',
    'shelltime.utils.yaml',
    'shelltime.utils.language',
  }
  for _, name in ipairs(modules) do
    package.loaded[name] = nil
  end
end

--- Reset config module state (config caching)
function M.reset_config()
  M.reset_module('shelltime.config')
end

--- Reset heartbeat module state (pending heartbeats, debounce cache)
function M.reset_heartbeat()
  M.reset_module('shelltime.heartbeat')
end

return M
