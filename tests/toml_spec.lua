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

  it('should keep the keys under an array of tables out of the table before it', function()
    -- As go-toml writes a config with Endpoints, after the root keys
    local parsed = toml.parse(table.concat({
      "Token = 'tok'",
      "APIEndpoint = 'https://api.shelltime.xyz'",
      '',
      '[codeTracking]',
      'enabled = true',
      '',
      '[[ENDPOINTS]]',
      "APIEndpoint = 'http://localhost:27312'",
      "Token = 'dev'",
      '',
      '[[ENDPOINTS]]',
      "APIEndpoint = 'http://localhost:8080'",
      '',
      '[[a.b]]',
      'enabled = false',
    }, '\n'))

    assert.equals('tok', parsed.Token)
    assert.equals('https://api.shelltime.xyz', parsed.APIEndpoint)
    assert.is_true(parsed.codeTracking.enabled)
    assert.is_nil(parsed.codeTracking.APIEndpoint)
    assert.equals(2, #parsed.ENDPOINTS)
    assert.equals('http://localhost:27312', parsed.ENDPOINTS[1].APIEndpoint)
    assert.equals('dev', parsed.ENDPOINTS[1].Token)
    assert.equals('http://localhost:8080', parsed.ENDPOINTS[2].APIEndpoint)
    assert.is_false(parsed.a.b[1].enabled)
  end)

  it('should return an error for a missing file', function()
    local result, err = toml.load_file('/nonexistent/config.toml')
    assert.is_nil(result)
    assert.is_string(err)
  end)
end)
