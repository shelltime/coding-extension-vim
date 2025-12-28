-- Tests for shelltime/init.lua (public API)
describe('shelltime', function()
  local shelltime
  local stub = require('luassert.stub')

  before_each(function()
    -- Reset all modules
    package.loaded['shelltime'] = nil
    package.loaded['shelltime.config'] = nil
    package.loaded['shelltime.heartbeat'] = nil
    package.loaded['shelltime.sender'] = nil
    package.loaded['shelltime.socket'] = nil

    shelltime = require('shelltime')
  end)

  after_each(function()
    -- Clean up
    pcall(function() shelltime.disable() end)
  end)

  describe('setup', function()
    it('should initialize without errors', function()
      assert.has_no_errors(function()
        shelltime.setup()
      end)
    end)

    it('should accept options table', function()
      assert.has_no_errors(function()
        shelltime.setup({ config = '/custom/path.yaml' })
      end)
    end)

    it('should accept empty options table', function()
      assert.has_no_errors(function()
        shelltime.setup({})
      end)
    end)

    it('should start tracking when enabled in config', function()
      shelltime.setup()
      -- Default config has enabled = true
      assert.is_true(shelltime.is_enabled())
    end)

    it('should only initialize once', function()
      shelltime.setup()
      local first_enabled = shelltime.is_enabled()

      shelltime.setup()  -- Should be no-op
      assert.equals(first_enabled, shelltime.is_enabled())
    end)
  end)

  describe('enable', function()
    it('should require setup first', function()
      -- Without setup, enable should warn
      package.loaded['shelltime'] = nil
      local fresh = require('shelltime')

      local notify_stub = stub(vim, 'notify')
      fresh.enable()

      assert.stub(notify_stub).was_called()
      notify_stub:revert()
    end)

    it('should enable tracking after setup', function()
      shelltime.setup()
      shelltime.disable()
      assert.is_false(shelltime.is_enabled())

      shelltime.enable()
      assert.is_true(shelltime.is_enabled())
    end)

    it('should be idempotent', function()
      shelltime.setup()

      shelltime.enable()
      assert.is_true(shelltime.is_enabled())

      shelltime.enable()  -- Second call should be no-op
      assert.is_true(shelltime.is_enabled())
    end)
  end)

  describe('disable', function()
    it('should disable tracking', function()
      shelltime.setup()
      assert.is_true(shelltime.is_enabled())

      shelltime.disable()
      assert.is_false(shelltime.is_enabled())
    end)

    it('should be safe to call multiple times', function()
      shelltime.setup()

      assert.has_no_errors(function()
        shelltime.disable()
        shelltime.disable()
      end)
    end)

    it('should be safe when not setup', function()
      package.loaded['shelltime'] = nil
      local fresh = require('shelltime')

      assert.has_no_errors(function()
        fresh.disable()
      end)
    end)
  end)

  describe('is_enabled', function()
    it('should return boolean', function()
      shelltime.setup()
      local enabled = shelltime.is_enabled()
      assert.is_boolean(enabled)
    end)

    it('should return false before setup', function()
      package.loaded['shelltime'] = nil
      local fresh = require('shelltime')
      assert.is_false(fresh.is_enabled())
    end)

    it('should reflect current state', function()
      shelltime.setup()
      assert.is_true(shelltime.is_enabled())

      shelltime.disable()
      assert.is_false(shelltime.is_enabled())

      shelltime.enable()
      assert.is_true(shelltime.is_enabled())
    end)
  end)

  describe('flush', function()
    it('should warn when not enabled', function()
      shelltime.setup()
      shelltime.disable()

      local notify_stub = stub(vim, 'notify')
      shelltime.flush()

      assert.stub(notify_stub).was_called()
      notify_stub:revert()
    end)

    it('should flush without error when enabled', function()
      shelltime.setup()

      assert.has_no_errors(function()
        shelltime.flush()
      end)
    end)
  end)

  describe('status', function()
    it('should display status information', function()
      shelltime.setup()

      local notify_stub = stub(vim, 'notify')

      shelltime.status()

      -- Status is async, wait a bit
      vim.wait(6000, function()
        return notify_stub.calls and #notify_stub.calls > 0
      end, 100)

      assert.stub(notify_stub).was_called()
      notify_stub:revert()
    end)

    it('should not error when called', function()
      shelltime.setup()

      assert.has_no_errors(function()
        shelltime.status()
      end)
    end)
  end)

  describe('module exports', function()
    it('should export setup function', function()
      assert.is_function(shelltime.setup)
    end)

    it('should export enable function', function()
      assert.is_function(shelltime.enable)
    end)

    it('should export disable function', function()
      assert.is_function(shelltime.disable)
    end)

    it('should export is_enabled function', function()
      assert.is_function(shelltime.is_enabled)
    end)

    it('should export flush function', function()
      assert.is_function(shelltime.flush)
    end)

    it('should export status function', function()
      assert.is_function(shelltime.status)
    end)
  end)

  describe('integration', function()
    it('should support full enable/disable cycle', function()
      shelltime.setup()
      assert.is_true(shelltime.is_enabled())

      shelltime.disable()
      assert.is_false(shelltime.is_enabled())

      shelltime.enable()
      assert.is_true(shelltime.is_enabled())

      shelltime.disable()
      assert.is_false(shelltime.is_enabled())
    end)

    it('should work with custom config path', function()
      local helpers = require('tests.helpers')
      local config_path = helpers.fixture_path('config_valid.yaml')

      shelltime.setup({ config = config_path })
      assert.is_true(shelltime.is_enabled())
    end)

    it('should respect disabled config', function()
      local helpers = require('tests.helpers')
      local config_path = helpers.fixture_path('config_disabled.yaml')

      package.loaded['shelltime'] = nil
      package.loaded['shelltime.config'] = nil
      package.loaded['shelltime.heartbeat'] = nil
      package.loaded['shelltime.sender'] = nil
      package.loaded['shelltime.socket'] = nil

      local fresh = require('shelltime')
      fresh.setup({ config = config_path })

      -- When config has enabled: false, tracking should not start
      assert.is_false(fresh.is_enabled())
    end)
  end)
end)
