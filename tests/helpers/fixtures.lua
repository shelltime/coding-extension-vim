-- Test fixtures and factory functions
local M = {}

--- Create a heartbeat data object
---@param overrides table|nil Field overrides
---@return table heartbeat
function M.heartbeat(overrides)
  return vim.tbl_extend('force', {
    heartbeatId = 'test-uuid-1234',
    entity = '/project/src/main.lua',
    entityType = 'file',
    category = 'coding',
    time = 1703750000,
    project = 'myproject',
    projectRootPath = '/project',
    branch = 'main',
    language = 'lua',
    lines = 100,
    lineNumber = 50,
    cursorPosition = 10,
    editor = 'neovim',
    editorVersion = '0.10.0',
    plugin = 'shelltime',
    pluginVersion = '0.1.0',
    machine = 'localhost',
    os = 'macOS',
    osVersion = '14.0.0',
    isWrite = false,
  }, overrides or {})
end

--- Create config object
---@param overrides table|nil Field overrides
---@return table config
function M.config(overrides)
  return vim.tbl_extend('force', {
    socket_path = '/tmp/shelltime.sock',
    enabled = true,
    heartbeat_interval = 120000,
    debounce_interval = 30000,
    debug = false,
  }, overrides or {})
end

--- Sample YAML content for testing
M.yaml_samples = {
  simple = [[
enabled: true
socketPath: /tmp/test.sock
debug: false
]],

  nested = [[
codeTracking:
  enabled: true
  interval: 30000
socketPath: /tmp/test.sock
]],

  with_comments = [[
# This is a comment
enabled: true
# Another comment
socketPath: /tmp/test.sock
]],

  with_strings = [[
name: "quoted string"
path: 'single quoted'
unquoted: plain string
]],

  with_numbers = [[
integer: 42
float: 3.14
negative: -10
]],

  with_booleans = [[
enabled: true
disabled: false
]],

  with_nulls = [[
empty:
nothing: null
tilde: ~
]],

  invalid = [[
bad yaml [[[
  nested: wrong
]],
}

return M
