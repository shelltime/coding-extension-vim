-- Tests for shelltime/utils/toml.lua
describe('shelltime.utils.toml', function()
  local toml

  before_each(function()
    package.loaded['shelltime.utils.toml'] = nil
    toml = require('shelltime.utils.toml')
  end)

  it('should parse the keys the CLI writes', function()
    local parsed = toml.parse(table.concat({
      'Token = "abc"',
      'APIEndpoint = "https://api.shelltime.xyz"',
      "WebEndpoint = 'https://shelltime.xyz'",
      'FlushCount = 10',
      'socketPath = "/tmp/custom.sock" # where the daemon listens',
      '',
      '[codeTracking]',
      'enabled = true',
      '',
      '# comment line',
      '[aiCodeOtel]',
      'enabled = false',
      'grpcPort = 54027',
    }, '\n'))

    assert.equals('abc', parsed.Token)
    assert.equals('https://api.shelltime.xyz', parsed.APIEndpoint)
    assert.equals('https://shelltime.xyz', parsed.WebEndpoint)
    assert.equals(10, parsed.FlushCount)
    assert.equals('/tmp/custom.sock', parsed.socketPath)
    assert.is_true(parsed.codeTracking.enabled)
    assert.is_false(parsed.aiCodeOtel.enabled)
    assert.equals(54027, parsed.aiCodeOtel.grpcPort)
  end)

  it('should keep a # inside a quoted string', function()
    assert.equals('/tmp/a#b.sock', toml.parse('socketPath = "/tmp/a#b.sock"').socketPath)
  end)

  it('should nest dotted tables', function()
    assert.is_true(toml.parse('[a.b]\nc = true').a.b.c)
  end)

  it('should return an error for a missing file', function()
    local result, err = toml.load_file('/nonexistent/config.toml')
    assert.is_nil(result)
    assert.is_string(err)
  end)
end)
