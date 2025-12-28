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
        callback(true, nil)
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
        callback(true, nil)
      end)

      assert.has_no_errors(function()
        sender.flush()
      end)
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
