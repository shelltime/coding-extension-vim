-- Tests for shelltime/offline.lua
describe('shelltime.offline', function()
  local offline
  local dir

  before_each(function()
    package.loaded['shelltime.offline'] = nil
    offline = require('shelltime.offline')
    dir = vim.fn.tempname()
  end)

  after_each(function()
    vim.fn.delete(dir, 'rf')
  end)

  it('should append payload lines in the format the daemon resends', function()
    local path = dir .. '/.shelltime/coding-heartbeat.data.log'

    assert.is_true(offline.save({ { heartbeatId = 'a' }, { heartbeatId = 'b' } }, path))
    assert.is_true(offline.save({ { heartbeatId = 'c' } }, path))

    local lines = vim.fn.readfile(path)
    assert.equals(2, #lines)
    local first = vim.json.decode(lines[1])
    assert.equals(2, #first.heartbeats)
    assert.equals('a', first.heartbeats[1].heartbeatId)
  end)

  it('should split a backlog into bounded payloads', function()
    local path = dir .. '/log'
    local heartbeats = {}
    for i = 1, 501 do
      heartbeats[i] = { heartbeatId = tostring(i) }
    end

    offline.save(heartbeats, path)

    local lines = vim.fn.readfile(path)
    assert.equals(500, #vim.json.decode(lines[1]).heartbeats)
    assert.equals(1, #vim.json.decode(lines[2]).heartbeats)
  end)

  it('should not write when there is nothing to keep', function()
    local path = dir .. '/log'
    assert.is_true(offline.save({}, path))
    assert.equals(0, vim.fn.filereadable(path))
  end)

  it('should use the daemon file under HOME by default', function()
    assert.equals(os.getenv('HOME') .. '/.shelltime/coding-heartbeat.data.log', offline.default_path())
  end)
end)
