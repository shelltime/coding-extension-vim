-- Tests for shelltime/sender.lua
describe('shelltime.sender', function()
  local sender
  local socket
  local heartbeat
  local config
  local stub = require('luassert.stub')

  before_each(function()
    -- Reset modules
    package.loaded['shelltime.sender'] = nil
    package.loaded['shelltime.socket'] = nil
    package.loaded['shelltime.heartbeat'] = nil
    package.loaded['shelltime.config'] = nil

    config = require('shelltime.config')
    config.setup({ config = '/nonexistent/config.yaml' })

    heartbeat = require('shelltime.heartbeat')
    socket = require('shelltime.socket')
    sender = require('shelltime.sender')
  end)

  after_each(function()
    -- Stop timer if running
    pcall(function() sender.stop() end)
  end)

  describe('start', function()
    it('should create flush timer without error', function()
      assert.has_no_errors(function()
        sender.start()
      end)
      sender.stop()
    end)

    it('should not create duplicate timer on double start', function()
      sender.start()
      assert.has_no_errors(function()
        sender.start()  -- Should be no-op
      end)
      sender.stop()
    end)

    it('should use configured interval', function()
      local interval = config.get('heartbeat_interval')
      assert.equals(120000, interval)

      sender.start()
      sender.stop()
    end)
  end)

  describe('stop', function()
    it('should stop and close timer', function()
      sender.start()
      assert.has_no_errors(function()
        sender.stop()
      end)
    end)

    it('should be safe when not started', function()
      assert.has_no_errors(function()
        sender.stop()
      end)
    end)

    it('should be safe to call multiple times', function()
      sender.start()
      assert.has_no_errors(function()
        sender.stop()
        sender.stop()
      end)
    end)
  end)

  describe('flush', function()
    local socket_stub

    after_each(function()
      if socket_stub and socket_stub.revert then
        socket_stub:revert()
        socket_stub = nil
      end
    end)

    it('should call socket.send_heartbeats when there are heartbeats', function()
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('ok', nil)
      end)

      local called = false
      sender.flush(function(success, err)
        called = true
      end)

      vim.wait(100, function() return called end)
    end)

    it('should handle empty heartbeat queue', function()
      socket_stub = stub(socket, 'send_heartbeats')

      local called = false
      sender.flush(function(success, err)
        called = true
        assert.is_true(success)
      end)

      vim.wait(100, function() return called end)
    end)

    it('should work without callback', function()
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('ok', nil)
      end)

      assert.has_no_errors(function()
        sender.flush()
      end)
    end)

    it('should re-queue heartbeats when the send fails', function()
      heartbeat.requeue({ { entity = 'a' }, { entity = 'b' } })
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('failed', 'Connection failed: ENOENT')
      end)

      local called = false
      sender.flush(function(success)
        called = true
        assert.is_false(success)
      end)

      vim.wait(100, function() return called end)
      assert.is_true(called)
      local pending = heartbeat.flush()
      assert.equals(2, #pending)
      assert.equals('a', pending[1].entity)
    end)

    it('should keep heartbeats and warn once when the daemon has code tracking off', function()
      heartbeat.requeue({ { entity = 'a' }, { entity = 'b' } })
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('disabled', 'code tracking is disabled in the daemon')
      end)
      local notify_stub = stub(vim, 'notify')

      local called = false
      sender.flush(function(success)
        called = true
        assert.is_false(success)
      end)
      vim.wait(100, function() return called end)

      assert.is_true(sender.is_tracking_disabled())
      assert.equals(2, heartbeat.get_pending_count())
      sender.flush()
      assert.stub(notify_stub).was_called(1)
      notify_stub:revert()
    end)

    it('should send a backlog in bounded messages and keep what was not delivered', function()
      local queued = {}
      for i = 1, 1201 do
        queued[i] = { entity = tostring(i) }
      end
      heartbeat.requeue(queued)
      local sizes = {}
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        table.insert(sizes, #heartbeats)
        callback(#sizes < 3 and 'ok' or 'failed', nil)
      end)

      local called = false
      sender.flush(function()
        called = true
      end)
      vim.wait(100, function() return called end)

      assert.same({ 500, 500, 201 }, sizes)
      local pending = heartbeat.flush()
      assert.equals(201, #pending)
      assert.equals('1001', pending[1].entity)
    end)

    it('should not keep heartbeats after a successful send', function()
      heartbeat.requeue({ { entity = 'a' } })
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('ok', nil)
      end)

      local called = false
      sender.flush(function()
        called = true
      end)

      vim.wait(100, function() return called end)
      assert.equals(0, heartbeat.get_pending_count())
    end)
  end)

  describe('exit_flush', function()
    local socket_stub
    local save_stub
    local offline = require('shelltime.offline')

    before_each(function()
      save_stub = stub(offline, 'save')
    end)

    after_each(function()
      save_stub:revert()
      if socket_stub and socket_stub.revert then
        socket_stub:revert()
        socket_stub = nil
      end
    end)

    it('should leave heartbeats for the daemon when it is not running', function()
      heartbeat.requeue({ { entity = 'a' }, { entity = 'b' } })
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('failed', 'Connection failed: ENOENT')
      end)

      sender.exit_flush(100)

      assert.stub(save_stub).was_called(1)
      assert.equals(2, #save_stub.calls[1].refs[1])
    end)

    it('should keep a send that got no answer in time', function()
      heartbeat.requeue({ { entity = 'a' } })
      socket_stub = stub(socket, 'send_heartbeats')

      sender.exit_flush(20)

      assert.equals('a', save_stub.calls[1].refs[1][1].entity)
    end)

    it('should leave nothing when the daemon took them', function()
      heartbeat.requeue({ { entity = 'a' } })
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        callback('ok', nil)
      end)

      sender.exit_flush(100)

      assert.equals(0, #save_stub.calls[1].refs[1])
    end)

    it('should wait for a send already in progress', function()
      heartbeat.requeue({ { entity = 'a' } })
      local answered = false
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        vim.defer_fn(function()
          answered = true
          callback('ok', nil)
        end, 20)
      end)

      sender.flush()
      sender.exit_flush(500)

      assert.is_true(answered)
      assert.stub(socket_stub).was_called(1)
      assert.equals(0, #save_stub.calls[1].refs[1])
    end)

    it('should keep what a send in progress has not delivered', function()
      -- A periodic flush of a backlog is between chunks when Neovim exits
      local queued = {}
      for i = 1, 1200 do
        queued[i] = { entity = tostring(i) }
      end
      heartbeat.requeue(queued)
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        if heartbeats[1].entity == '1' then
          vim.defer_fn(function()
            callback('ok', nil)
          end, 10)
        end
      end)

      sender.flush()
      heartbeat.requeue({ { entity = 'newer' } })
      sender.exit_flush(100)

      -- Heartbeats 501-1200, then the one queued later
      local saved = save_stub.calls[1].refs[1]
      assert.equals(701, #saved)
      assert.equals('501', saved[1].entity)
      assert.equals('1200', saved[700].entity)
      assert.equals('newer', saved[701].entity)
    end)

    it('should not queue again what it saved when the answer comes late', function()
      heartbeat.requeue({ { entity = 'a' } })
      local answer
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        answer = callback
      end)

      sender.exit_flush(20)
      answer('failed', 'Connection timeout')

      assert.equals('a', save_stub.calls[1].refs[1][1].entity)
      assert.equals(0, heartbeat.get_pending_count())
    end)
  end)

  describe('flush_sync', function()
    local socket_stub

    after_each(function()
      if socket_stub and socket_stub.revert then
        socket_stub:revert()
        socket_stub = nil
      end
    end)

    it('should wait for a scheduled send to finish', function()
      heartbeat.requeue({ { entity = 'a' } })
      socket_stub = stub(socket, 'send_heartbeats')
      socket_stub.invokes(function(heartbeats, callback)
        vim.schedule(function()
          callback('ok', nil)
        end)
      end)

      assert.is_true(sender.flush_sync(500))
      assert.stub(socket_stub).was_called(1)
      assert.equals(0, heartbeat.get_pending_count())
    end)

    it('should give up after the timeout', function()
      heartbeat.requeue({ { entity = 'a' } })
      socket_stub = stub(socket, 'send_heartbeats')

      assert.is_false(sender.flush_sync(20))
    end)
  end)

  describe('exit flush', function()
    it('should register a VimLeavePre autocmd on start', function()
      sender.start()

      local autocmds = vim.api.nvim_get_autocmds({ group = 'ShellTimeSender', event = 'VimLeavePre' })
      assert.equals(1, #autocmds)

      sender.stop()
    end)

    it('should remove the autocmd on stop', function()
      sender.start()
      sender.stop()

      local ok = pcall(vim.api.nvim_get_autocmds, { group = 'ShellTimeSender' })
      assert.is_false(ok)
    end)
  end)

  describe('is_connected', function()
    it('should return boolean', function()
      local connected = sender.is_connected()
      assert.is_boolean(connected)
    end)

    it('should initially be false', function()
      local connected = sender.is_connected()
      assert.is_false(connected)
    end)
  end)

  describe('check_status', function()
    local socket_stub

    after_each(function()
      if socket_stub and socket_stub.revert then
        socket_stub:revert()
        socket_stub = nil
      end
    end)

    it('should call socket.get_status', function()
      socket_stub = stub(socket, 'get_status')
      socket_stub.invokes(function(callback)
        callback({ version = '1.0.0' }, nil)
      end)

      local called = false
      sender.check_status(function(connected, status)
        called = true
        assert.is_true(connected)
        assert.is_table(status)
      end)

      vim.wait(100, function() return called end)
      assert.is_true(called)
    end)

    it('should handle connection failure', function()
      socket_stub = stub(socket, 'get_status')
      socket_stub.invokes(function(callback)
        callback(nil, 'Connection refused')
      end)

      local called = false
      sender.check_status(function(connected, status)
        called = true
        assert.is_false(connected)
      end)

      vim.wait(100, function() return called end)
      assert.is_true(called)
    end)

    it('should update is_connected state on success', function()
      socket_stub = stub(socket, 'get_status')
      socket_stub.invokes(function(callback)
        callback({ version = '1.0.0' }, nil)
      end)

      local called = false
      sender.check_status(function(connected, status)
        called = true
      end)

      vim.wait(100, function() return called end)
      assert.is_true(sender.is_connected())
    end)

    it('should update is_connected state on failure', function()
      socket_stub = stub(socket, 'get_status')
      socket_stub.invokes(function(callback)
        callback(nil, 'Error')
      end)

      local called = false
      sender.check_status(function(connected, status)
        called = true
      end)

      vim.wait(100, function() return called end)
      assert.is_false(sender.is_connected())
    end)
  end)

  describe('module exports', function()
    it('should export start function', function()
      assert.is_function(sender.start)
    end)

    it('should export stop function', function()
      assert.is_function(sender.stop)
    end)

    it('should export flush function', function()
      assert.is_function(sender.flush)
    end)

    it('should export is_connected function', function()
      assert.is_function(sender.is_connected)
    end)

    it('should export check_status function', function()
      assert.is_function(sender.check_status)
    end)
  end)
end)
