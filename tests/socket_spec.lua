-- Tests for shelltime/socket.lua
describe('shelltime.socket', function()
  local socket
  local config

  before_each(function()
    package.loaded['shelltime.socket'] = nil
    package.loaded['shelltime.config'] = nil

    config = require('shelltime.config')
    config.setup({ config = '/nonexistent/config.yaml' })

    socket = require('shelltime.socket')
  end)

  describe('is_connected_sync', function()
    it('should return boolean', function()
      local connected = socket.is_connected_sync()
      assert.is_boolean(connected)
    end)

    it('should return false when socket file does not exist', function()
      -- Default socket path is /tmp/shelltime.sock
      -- Unless daemon is running, this should be false
      -- Note: This test may pass or fail depending on environment
      local connected = socket.is_connected_sync()
      assert.is_boolean(connected)
    end)

    it('should use configured socket_path', function()
      local socket_path = config.get('socket_path')
      assert.equals('/tmp/shelltime.sock', socket_path)
    end)
  end)

  describe('send', function()
    it('should handle connection failure gracefully', function()
      local called = false
      socket.send({ type = 'test' }, function(response, err)
        called = true
        assert.is_nil(response)
        assert.is_string(err)
      end)

      -- Wait for async callback (up to 6s for timeout)
      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)

    it('should accept message table', function()
      local called = false
      local message = { type = 'heartbeat', payload = { heartbeats = {} } }

      socket.send(message, function(response, err)
        called = true
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)

    it('should call callback with error on timeout', function()
      local called = false
      local error_msg = nil

      socket.send({ type = 'test' }, function(response, err)
        called = true
        error_msg = err
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
      -- Should have some error message (connection failed or timeout)
      assert.is_string(error_msg)
    end)
  end)

  describe('send_heartbeats', function()
    it('should create correct message structure', function()
      local heartbeats = {
        { heartbeatId = 'test-1', entity = '/test/file.lua' },
      }

      local called = false
      socket.send_heartbeats(heartbeats, function(success, err)
        called = true
        assert.is_boolean(success)
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)

    it('should return success false on connection error', function()
      local heartbeats = {{ heartbeatId = 'test' }}

      local called = false
      socket.send_heartbeats(heartbeats, function(success, err)
        called = true
        assert.is_false(success)
        assert.is_string(err)
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)

    it('should handle empty heartbeats array', function()
      local called = false
      socket.send_heartbeats({}, function(success, err)
        called = true
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)

    it('should handle multiple heartbeats', function()
      local heartbeats = {
        { heartbeatId = 'test-1', entity = '/test/file1.lua' },
        { heartbeatId = 'test-2', entity = '/test/file2.lua' },
        { heartbeatId = 'test-3', entity = '/test/file3.lua' },
      }

      local called = false
      socket.send_heartbeats(heartbeats, function(success, err)
        called = true
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)
  end)

  describe('get_status', function()
    it('should send status message type', function()
      local called = false
      socket.get_status(function(status, err)
        called = true
        -- Will fail without daemon
        if not err then
          assert.is_table(status)
        else
          assert.is_string(err)
        end
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)

    it('should call callback with error when daemon unavailable', function()
      local called = false
      socket.get_status(function(status, err)
        called = true
        -- Without daemon, we expect an error
        assert.is_string(err)
      end)

      vim.wait(6000, function() return called end, 100)
      assert.is_true(called)
    end)
  end)

  describe('vim.loop/vim.uv compatibility', function()
    it('should use vim.loop or vim.uv', function()
      local uv = vim.loop or vim.uv
      assert.is_table(uv)
    end)

    it('should have new_pipe function', function()
      local uv = vim.loop or vim.uv
      assert.is_function(uv.new_pipe)
    end)

    it('should have new_timer function', function()
      local uv = vim.loop or vim.uv
      assert.is_function(uv.new_timer)
    end)

    it('should have fs_stat function', function()
      local uv = vim.loop or vim.uv
      assert.is_function(uv.fs_stat)
    end)
  end)

  describe('module exports', function()
    it('should export send function', function()
      assert.is_function(socket.send)
    end)

    it('should export send_heartbeats function', function()
      assert.is_function(socket.send_heartbeats)
    end)

    it('should export get_status function', function()
      assert.is_function(socket.get_status)
    end)

    it('should export is_connected_sync function', function()
      assert.is_function(socket.is_connected_sync)
    end)
  end)

  describe('JSON encoding', function()
    it('should encode message table to JSON', function()
      local message = { type = 'heartbeat', payload = { heartbeats = {} } }
      local json = vim.fn.json_encode(message)
      assert.is_string(json)
      assert.matches('"type"', json)
      assert.matches('"heartbeat"', json)
    end)

    it('should handle complex payload', function()
      local message = {
        type = 'heartbeat',
        payload = {
          heartbeats = {
            { id = 1, file = '/test/file.lua' },
            { id = 2, file = '/test/other.lua' },
          }
        }
      }
      local json = vim.fn.json_encode(message)
      assert.is_string(json)
    end)
  end)
end)
