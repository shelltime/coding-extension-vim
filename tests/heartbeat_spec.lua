-- Tests for shelltime/heartbeat.lua
describe('shelltime.heartbeat', function()
  local heartbeat
  local config
  local helpers
  local stub = require('luassert.stub')

  local api_stubs = {}

  before_each(function()
    -- Reset modules
    package.loaded['shelltime.heartbeat'] = nil
    package.loaded['shelltime.config'] = nil
    package.loaded['shelltime.utils.system'] = nil
    package.loaded['shelltime.utils.git'] = nil

    helpers = require('tests.helpers')
    config = require('shelltime.config')
    config.setup({ config = '/nonexistent/config.yaml' })

    heartbeat = require('shelltime.heartbeat')
  end)

  after_each(function()
    -- Revert all stubs
    for _, s in pairs(api_stubs) do
      if s and s.revert then
        s:revert()
      end
    end
    api_stubs = {}

    -- Stop heartbeat if running
    pcall(function() heartbeat.stop() end)
  end)

  describe('flush', function()
    it('should return empty array initially', function()
      local pending = heartbeat.flush()
      assert.is_table(pending)
      assert.equals(0, #pending)
    end)

    it('should clear pending heartbeats after flush', function()
      local pending1 = heartbeat.flush()
      local pending2 = heartbeat.flush()

      assert.equals(0, #pending1)
      assert.equals(0, #pending2)
    end)

    it('should return array type', function()
      local pending = heartbeat.flush()
      assert.is_table(pending)
    end)
  end)

  describe('get_pending_count', function()
    it('should return 0 initially', function()
      assert.equals(0, heartbeat.get_pending_count())
    end)

    it('should return number type', function()
      local count = heartbeat.get_pending_count()
      assert.is_number(count)
    end)

    it('should be consistent with flush result length', function()
      local count = heartbeat.get_pending_count()
      local pending = heartbeat.flush()
      assert.equals(count, #pending)
    end)
  end)

  describe('start/stop', function()
    it('should create augroup on start', function()
      heartbeat.start()

      -- Verify augroup exists
      local ok, groups = pcall(vim.api.nvim_get_autocmds, { group = 'ShellTimeHeartbeat' })
      assert.is_true(ok)
      assert.is_table(groups)

      heartbeat.stop()
    end)

    it('should not create duplicate augroup on double start', function()
      heartbeat.start()
      heartbeat.start()  -- Should be no-op

      local ok, groups = pcall(vim.api.nvim_get_autocmds, { group = 'ShellTimeHeartbeat' })
      assert.is_true(ok)
      assert.is_table(groups)

      heartbeat.stop()
    end)

    it('should be safe to call stop when not started', function()
      assert.has_no_errors(function()
        heartbeat.stop()
      end)
    end)

    it('should be safe to call stop multiple times', function()
      heartbeat.start()
      assert.has_no_errors(function()
        heartbeat.stop()
        heartbeat.stop()
      end)
    end)

    it('should register autocmds for expected events', function()
      heartbeat.start()

      local groups = vim.api.nvim_get_autocmds({ group = 'ShellTimeHeartbeat' })
      local events = {}
      for _, ac in ipairs(groups) do
        events[ac.event] = true
      end

      -- Should have autocmds for these events
      assert.is_true(events['BufEnter'] or false)
      assert.is_true(events['TextChanged'] or false)
      assert.is_true(events['TextChangedI'] or false)
      assert.is_true(events['BufWritePost'] or false)
      assert.is_true(events['CursorMoved'] or false)
      assert.is_true(events['CursorMovedI'] or false)

      heartbeat.stop()
    end)
  end)

  describe('clear_cache', function()
    it('should reset debounce tracking', function()
      heartbeat.clear_cache()
      assert.equals(0, heartbeat.get_pending_count())
    end)

    it('should not error when called multiple times', function()
      assert.has_no_errors(function()
        heartbeat.clear_cache()
        heartbeat.clear_cache()
      end)
    end)
  end)

  describe('module exports', function()
    it('should export start function', function()
      assert.is_function(heartbeat.start)
    end)

    it('should export stop function', function()
      assert.is_function(heartbeat.stop)
    end)

    it('should export flush function', function()
      assert.is_function(heartbeat.flush)
    end)

    it('should export get_pending_count function', function()
      assert.is_function(heartbeat.get_pending_count)
    end)

    it('should export clear_cache function', function()
      assert.is_function(heartbeat.clear_cache)
    end)
  end)

  describe('debounce_interval configuration', function()
    it('should use configured debounce_interval', function()
      local debounce = config.get('debounce_interval')
      assert.equals(30000, debounce)
    end)
  end)

  describe('buffer validation (integration)', function()
    -- These tests verify buffer validation through behavior

    it('should not crash when processing invalid buffer', function()
      heartbeat.start()

      -- Create and immediately delete a buffer to test invalid buffer handling
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_delete(bufnr, { force = true })

      -- The autocmd might fire but should not crash
      assert.equals(0, heartbeat.get_pending_count())

      heartbeat.stop()
    end)
  end)
end)
