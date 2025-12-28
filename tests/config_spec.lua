-- Tests for shelltime/config.lua
describe('shelltime.config', function()
  local config
  local helpers

  before_each(function()
    -- Reset config module to clear cache
    package.loaded['shelltime.config'] = nil
    package.loaded['shelltime.utils.yaml'] = nil
    config = require('shelltime.config')
    helpers = require('tests.helpers')
  end)

  describe('setup', function()
    it('should accept custom config path', function()
      local custom_path = helpers.fixture_path('config_valid.yaml')
      config.setup({ config = custom_path })

      local path = config.get_config_path()
      assert.equals(custom_path, path)
    end)

    it('should use default path when no options provided', function()
      config.setup()

      local path = config.get_config_path()
      assert.equals('~/.shelltime/config.yaml', path)
    end)

    it('should use default path when empty options provided', function()
      config.setup({})

      local path = config.get_config_path()
      assert.equals('~/.shelltime/config.yaml', path)
    end)

    it('should reset cached config on setup', function()
      -- First setup with one path
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })
      local config1 = config.get_config()

      -- Reset and setup with different path
      package.loaded['shelltime.config'] = nil
      config = require('shelltime.config')
      config.setup({ config = helpers.fixture_path('config_minimal.yaml') })
      local config2 = config.get_config()

      -- Configs should potentially differ based on file contents
      assert.is_table(config1)
      assert.is_table(config2)
    end)
  end)

  describe('get_config', function()
    it('should return default values when config file missing', function()
      config.setup({ config = '/nonexistent/config.yaml' })

      local cfg = config.get_config()
      assert.equals('/tmp/shelltime.sock', cfg.socket_path)
      assert.is_true(cfg.enabled)
      assert.equals(120000, cfg.heartbeat_interval)
      assert.equals(30000, cfg.debounce_interval)
      assert.is_false(cfg.debug)
    end)

    it('should merge file config with defaults', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })

      local cfg = config.get_config()
      assert.is_table(cfg)
      -- Should have all default keys
      assert.is_not_nil(cfg.socket_path)
      assert.is_not_nil(cfg.enabled)
      assert.is_not_nil(cfg.heartbeat_interval)
      assert.is_not_nil(cfg.debounce_interval)
      assert.is_not_nil(cfg.debug)
    end)

    it('should cache config and return same instance', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })

      local cfg1 = config.get_config()
      local cfg2 = config.get_config()
      assert.equals(cfg1, cfg2)  -- Same table reference
    end)

    it('should map socketPath from YAML to socket_path', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })
      local cfg = config.get_config()
      assert.equals('/tmp/shelltime-test.sock', cfg.socket_path)
    end)

    it('should map codeTracking.enabled to enabled', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })
      local cfg = config.get_config()
      assert.is_true(cfg.enabled)
    end)

    it('should map heartbeatInterval from YAML', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })
      local cfg = config.get_config()
      assert.equals(60000, cfg.heartbeat_interval)
    end)

    it('should map debounceInterval from YAML', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })
      local cfg = config.get_config()
      assert.equals(15000, cfg.debounce_interval)
    end)

    it('should handle disabled config', function()
      config.setup({ config = helpers.fixture_path('config_disabled.yaml') })
      local cfg = config.get_config()
      assert.is_false(cfg.enabled)
    end)
  end)

  describe('get', function()
    before_each(function()
      config.setup({ config = '/nonexistent/config.yaml' })
    end)

    it('should return specific config value', function()
      local socket = config.get('socket_path')
      assert.equals('/tmp/shelltime.sock', socket)
    end)

    it('should return nil for unknown key', function()
      local unknown = config.get('nonexistent_key')
      assert.is_nil(unknown)
    end)

    it('should return boolean for enabled', function()
      local enabled = config.get('enabled')
      assert.is_boolean(enabled)
    end)

    it('should return number for heartbeat_interval', function()
      local interval = config.get('heartbeat_interval')
      assert.is_number(interval)
    end)

    it('should return number for debounce_interval', function()
      local interval = config.get('debounce_interval')
      assert.is_number(interval)
    end)

    it('should return boolean for debug', function()
      local debug = config.get('debug')
      assert.is_boolean(debug)
    end)
  end)

  describe('is_enabled', function()
    it('should return true when enabled in defaults', function()
      config.setup({ config = '/nonexistent/config.yaml' })
      assert.is_true(config.is_enabled())
    end)

    it('should return false when disabled in config file', function()
      config.setup({ config = helpers.fixture_path('config_disabled.yaml') })
      assert.is_false(config.is_enabled())
    end)

    it('should return true when enabled in config file', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })
      assert.is_true(config.is_enabled())
    end)
  end)

  describe('get_config_path', function()
    it('should return default path before setup', function()
      local path = config.get_config_path()
      assert.equals('~/.shelltime/config.yaml', path)
    end)

    it('should return custom path after setup', function()
      local custom = '/custom/path/config.yaml'
      config.setup({ config = custom })
      assert.equals(custom, config.get_config_path())
    end)
  end)

  describe('caching behavior', function()
    it('should not reload when mtime unchanged', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })

      local cfg1 = config.get_config()
      local cfg2 = config.get_config()

      -- Should be the exact same table (cached)
      assert.equals(cfg1, cfg2)
    end)

    it('should return valid config after multiple get calls', function()
      config.setup({ config = helpers.fixture_path('config_valid.yaml') })

      for _ = 1, 10 do
        local cfg = config.get_config()
        assert.is_table(cfg)
        assert.is_not_nil(cfg.socket_path)
      end
    end)
  end)

  describe('default values', function()
    before_each(function()
      config.setup({ config = '/nonexistent/config.yaml' })
    end)

    it('should have correct default socket_path', function()
      assert.equals('/tmp/shelltime.sock', config.get('socket_path'))
    end)

    it('should have correct default enabled', function()
      assert.is_true(config.get('enabled'))
    end)

    it('should have correct default heartbeat_interval', function()
      assert.equals(120000, config.get('heartbeat_interval'))
    end)

    it('should have correct default debounce_interval', function()
      assert.equals(30000, config.get('debounce_interval'))
    end)

    it('should have correct default debug', function()
      assert.is_false(config.get('debug'))
    end)
  end)
end)
