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

    -- Let scheduled callbacks (the deferred BufEnter) run
    local function settle()
      vim.wait(20, function()
        return false
      end)
    end

    -- Open a named file buffer in the current window, dropping its BufEnter heartbeat
    local function open_buffer(path)
      local bufnr = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(bufnr, path)
      table.insert(buffers, bufnr)
      vim.api.nvim_set_current_buf(bufnr)
      settle()
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
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'edited' })

      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })

      assert.equals(2, heartbeat.get_pending_count())
    end)

    it('should count only the buffer a buffer loop ends in', function()
      -- :bufdo enters each buffer in one go; the user only sees the last
      local paths = { '/tmp/shelltime-test/loop1.lua', '/tmp/shelltime-test/loop2.lua', '/tmp/shelltime-test/loop3.lua' }
      for _, path in ipairs(paths) do
        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(bufnr, path)
        table.insert(buffers, bufnr)
        vim.api.nvim_set_current_buf(bufnr)
      end
      settle()

      local pending = heartbeat.flush()
      assert.equals(1, #pending)
      assert.equals(paths[3], pending[1].entity)
    end)

    it('should count saves once per debounce window and keep the last one', function()
      config._set_for_testing({ debounce_interval = 60000 })
      local bufnr = open_buffer('/tmp/shelltime-test/autosave.lua')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'a', 'b', 'c' })
      heartbeat.clear_cache()

      for line = 1, 3 do
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        vim.api.nvim_exec_autocmds('BufWritePost', { buffer = bufnr })
      end

      -- The window's write, then the last save inside it, where it happened
      assert.equals(2, heartbeat.get_pending_count())
      local pending = heartbeat.flush()
      assert.equals(2, #pending)
      assert.is_true(pending[1].isWrite)
      assert.equals(1, pending[1].lineNumber)
      assert.is_true(pending[2].isWrite)
      assert.equals(3, pending[2].lineNumber)
      assert.equals(0, #heartbeat.flush())
    end)

    it('should send a save inside the window ahead of the file\'s next heartbeat', function()
      config._set_for_testing({ debounce_interval = 60000 })
      local bufnr = open_buffer('/tmp/shelltime-test/save-then-edit.lua')
      heartbeat.clear_cache()
      local real_time = os.time
      local now = real_time()
      os.time = function()
        return now
      end

      local ok, err = pcall(function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'typed' })
        vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
        now = now + 5
        vim.api.nvim_exec_autocmds('BufWritePost', { buffer = bufnr })
        now = now + 60
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'typed more' })
        vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })
      end)
      os.time = real_time
      assert(ok, err)

      local pending = heartbeat.flush()
      assert.equals(3, #pending)
      assert.is_false(pending[1].isWrite)
      assert.is_true(pending[2].isWrite)
      assert.equals(pending[1].time + 5, pending[2].time)
      assert.is_false(pending[3].isWrite)
    end)

    it('should skip a text change that leaves the buffer unmodified', function()
      -- A reload from disk after a git checkout, a formatter or an AI agent
      local bufnr = open_buffer('/tmp/shelltime-test/reloaded.lua')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'from disk' })
      vim.bo[bufnr].modified = false

      vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufnr })

      assert.equals(0, heartbeat.get_pending_count())
    end)

    it('should attribute a write to the buffer written, not the current one', function()
      -- :wa writes other buffers while another one is current
      local other = open_buffer('/tmp/shelltime-test/other.lua')
      vim.api.nvim_buf_set_lines(other, 0, -1, false, { 'a', 'b', 'c' })
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      local current = open_buffer('/tmp/shelltime-test/current.lua')

      vim.api.nvim_exec_autocmds('BufWritePost', { buffer = other })

      local pending = heartbeat.flush()
      assert.equals(1, #pending)
      assert.equals('/tmp/shelltime-test/other.lua', pending[1].entity)
      assert.is_true(pending[1].isWrite)
      -- Where the cursor was left in that buffer, not the current window's
      assert.equals(3, pending[1].lineNumber)
      assert.equals(3, pending[1].lines)
      assert.equals(current, vim.api.nvim_get_current_buf())
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
