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

    it('should reset last activity state for duplicate detection', function()
      -- clear_cache should reset both debounce and duplicate tracking
      heartbeat.clear_cache()
      -- After clearing, the next event should not be considered duplicate
      assert.equals(0, heartbeat.get_pending_count())
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

  describe('requeue', function()
    it('should put heartbeats back ahead of newer ones', function()
      heartbeat.requeue({ { entity = 'newer' } })
      heartbeat.requeue({ { entity = 'older' } })

      local pending = heartbeat.flush()
      assert.equals(2, #pending)
      assert.equals('older', pending[1].entity)
      assert.equals('newer', pending[2].entity)
    end)

    it('should ignore an empty list', function()
      heartbeat.requeue({})
      assert.equals(0, heartbeat.get_pending_count())
    end)

    it('should cap the queue and drop the oldest heartbeats', function()
      local list = {}
      for i = 1, 5001 do
        list[i] = { entity = 'file-' .. i }
      end

      heartbeat.requeue(list)

      local pending = heartbeat.flush()
      assert.equals(5000, #pending)
      assert.equals('file-2', pending[1].entity)
      assert.equals('file-5001', pending[5000].entity)
    end)
  end)

  describe('autocmd events (integration)', function()
    local buffers = {}

    -- Open a named file buffer in the current window, dropping its BufEnter heartbeat
    local function open_buffer(path)
      local bufnr = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(bufnr, path)
      table.insert(buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)
      heartbeat.flush()
      return bufnr
    end

    before_each(function()
      config._set_for_testing({ debounce_interval = 0 })
      heartbeat.start()
    end)

    after_each(function()
      heartbeat.stop()
      for _, bufnr in ipairs(buffers) do
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
      buffers = {}
    end)

    it('should skip files inside .git', function()
      local bufnr = open_buffer('/tmp/shelltime-test/.git/COMMIT_EDITMSG')

      vim.api.nvim_exec_autocmds('BufWritePost', { buffer = bufnr })

      assert.equals(0, heartbeat.get_pending_count())
    end)

    it('should track directories that only look like .git', function()
      local bufnr = open_buffer('/tmp/shelltime-test/egit/main.lua')

      vim.api.nvim_exec_autocmds('BufWritePost', { buffer = bufnr })

      assert.equals(1, heartbeat.get_pending_count())
    end)

    it('should count edits that leave the cursor in place', function()
      local bufnr = open_buffer('/tmp/shelltime-test/edit.lua')

      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })

      assert.equals(2, heartbeat.get_pending_count())
    end)

    it('should skip repeated cursor events at the same position', function()
      local bufnr = open_buffer('/tmp/shelltime-test/nav.lua')

      vim.api.nvim_exec_autocmds('CursorMoved', { buffer = bufnr })
      vim.api.nvim_exec_autocmds('CursorMoved', { buffer = bufnr })

      assert.equals(0, heartbeat.get_pending_count())
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
