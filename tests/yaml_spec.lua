-- Tests for shelltime/utils/yaml.lua
describe('shelltime.utils.yaml', function()
  local yaml
  local helpers

  before_each(function()
    package.loaded['shelltime.utils.yaml'] = nil
    yaml = require('shelltime.utils.yaml')
    helpers = require('tests.helpers')
  end)

  describe('parse', function()
    describe('simple key-value pairs', function()
      it('should parse string values', function()
        local result = yaml.parse('key: value')
        assert.equals('value', result.key)
      end)

      it('should parse quoted strings with double quotes', function()
        local result = yaml.parse('key: "hello world"')
        assert.equals('hello world', result.key)
      end)

      it('should parse quoted strings with single quotes', function()
        local result = yaml.parse("key: 'hello world'")
        assert.equals('hello world', result.key)
      end)

      it('should parse integer values', function()
        local result = yaml.parse('count: 42')
        assert.equals(42, result.count)
      end)

      it('should parse negative numbers', function()
        local result = yaml.parse('offset: -10')
        assert.equals(-10, result.offset)
      end)

      it('should parse float values', function()
        local result = yaml.parse('ratio: 3.14')
        assert.equals(3.14, result.ratio)
      end)

      it('should parse boolean true', function()
        local result = yaml.parse('enabled: true')
        assert.is_true(result.enabled)
      end)

      it('should parse boolean false', function()
        local result = yaml.parse('enabled: false')
        assert.is_false(result.enabled)
      end)

      it('should parse null as nil', function()
        local result = yaml.parse('value: null')
        assert.is_nil(result.value)
      end)

      it('should parse tilde as nil', function()
        local result = yaml.parse('value: ~')
        assert.is_nil(result.value)
      end)

      it('should parse empty value as nested object', function()
        local result = yaml.parse('value:')
        assert.is_table(result.value)
      end)
    end)

    describe('nested objects', function()
      it('should parse one level of nesting', function()
        local content = [[
parent:
  child: value
]]
        local result = yaml.parse(content)
        assert.is_table(result.parent)
        assert.equals('value', result.parent.child)
      end)

      it('should parse multiple levels of nesting', function()
        local content = [[
level1:
  level2:
    level3: deep
]]
        local result = yaml.parse(content)
        assert.equals('deep', result.level1.level2.level3)
      end)

      it('should parse siblings at same level', function()
        local content = [[
parent:
  child1: one
  child2: two
]]
        local result = yaml.parse(content)
        assert.equals('one', result.parent.child1)
        assert.equals('two', result.parent.child2)
      end)

      it('should parse multiple top-level keys with nested children', function()
        local content = [[
section1:
  key1: val1
section2:
  key2: val2
]]
        local result = yaml.parse(content)
        assert.equals('val1', result.section1.key1)
        assert.equals('val2', result.section2.key2)
      end)
    end)

    describe('comments and whitespace', function()
      it('should ignore comment lines', function()
        local content = [[
# This is a comment
key: value
# Another comment
]]
        local result = yaml.parse(content)
        assert.equals('value', result.key)
      end)

      it('should ignore empty lines', function()
        local content = [[
key1: value1

key2: value2
]]
        local result = yaml.parse(content)
        assert.equals('value1', result.key1)
        assert.equals('value2', result.key2)
      end)

      it('should handle leading/trailing whitespace in values', function()
        local result = yaml.parse('key:   spaced value   ')
        assert.equals('spaced value', result.key)
      end)

      it('should ignore lines with only comments', function()
        local content = [[
# comment1
# comment2
key: value
]]
        local result = yaml.parse(content)
        assert.equals('value', result.key)
      end)
    end)

    describe('edge cases', function()
      it('should return empty table for empty content', function()
        local result = yaml.parse('')
        assert.is_table(result)
        assert.equals(0, vim.tbl_count(result))
      end)

      it('should handle keys with underscores', function()
        local result = yaml.parse('socket_path: /tmp/test.sock')
        assert.equals('/tmp/test.sock', result.socket_path)
      end)

      it('should handle file paths as values', function()
        local result = yaml.parse('path: /home/user/.config/file.yaml')
        assert.equals('/home/user/.config/file.yaml', result.path)
      end)

      it('should handle URLs as values', function()
        local result = yaml.parse('url: https://example.com/api')
        assert.equals('https://example.com/api', result.url)
      end)

      it('should handle multiple key-value pairs', function()
        local content = [[
key1: value1
key2: value2
key3: value3
]]
        local result = yaml.parse(content)
        assert.equals('value1', result.key1)
        assert.equals('value2', result.key2)
        assert.equals('value3', result.key3)
      end)
    end)

    describe('realistic config parsing', function()
      it('should parse shelltime config format', function()
        local content = [[
socketPath: /tmp/shelltime.sock
codeTracking:
  enabled: true
heartbeatInterval: 120000
debounceInterval: 30000
debug: false
]]
        local result = yaml.parse(content)
        assert.equals('/tmp/shelltime.sock', result.socketPath)
        assert.is_true(result.codeTracking.enabled)
        assert.equals(120000, result.heartbeatInterval)
        assert.equals(30000, result.debounceInterval)
        assert.is_false(result.debug)
      end)
    end)
  end)

  describe('load_file', function()
    it('should load and parse valid YAML file', function()
      local path = helpers.fixture_path('config_valid.yaml')
      local result, err = yaml.load_file(path)
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals('/tmp/shelltime-test.sock', result.socketPath)
    end)

    it('should return error for non-existent file', function()
      local result, err = yaml.load_file('/nonexistent/file.yaml')
      assert.is_nil(result)
      assert.is_string(err)
      assert.matches('Cannot open file', err)
    end)

    it('should handle empty file', function()
      local path = helpers.fixture_path('config_empty.yaml')
      local result, err = yaml.load_file(path)
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals(0, vim.tbl_count(result))
    end)

    it('should parse minimal config', function()
      local path = helpers.fixture_path('config_minimal.yaml')
      local result, err = yaml.load_file(path)
      assert.is_nil(err)
      assert.is_table(result)
      assert.is_true(result.enabled)
    end)

    it('should parse nested codeTracking config', function()
      local path = helpers.fixture_path('config_valid.yaml')
      local result, err = yaml.load_file(path)
      assert.is_nil(err)
      assert.is_table(result.codeTracking)
      assert.is_true(result.codeTracking.enabled)
    end)
  end)
end)
