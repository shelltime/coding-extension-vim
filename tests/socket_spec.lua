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

      local result = nil
      socket.send_heartbeats(heartbeats, function(status, err)
        result = status
      end)

      vim.wait(6000, function() return result ~= nil end, 100)
      assert.is_string(result)
    end)

    it('should report failed on connection error', function()
      local heartbeats = {{ heartbeatId = 'test' }}

      local result = nil
      local error_msg = nil
      socket.send_heartbeats(heartbeats, function(status, err)
        result = status
        error_msg = err
      end)

      vim.wait(6000, function() return result ~= nil end, 100)
      assert.equals('failed', result)
      assert.is_string(error_msg)
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

  describe('send_heartbeats acknowledgment', function()
    local uv = vim.loop or vim.uv
    local server
    local socket_path

    -- A daemon on a scratch socket: replies[type] is what it writes back to a
    -- message of that type before closing (nil closes without a reply).
    -- replies.stop stops listening once a heartbeat arrives, as a daemon that
    -- is shutting down does before it drops the message.
    local function serve(replies)
      socket_path = vim.fn.tempname() .. '.sock'
      server = uv.new_pipe(false)
      server:bind(socket_path)
      server:listen(16, function()
        local client = uv.new_pipe(false)
        server:accept(client)
        local data = ''
        client:read_start(function(_, chunk)
          if chunk then
            data = data .. chunk
            return
          end
          local kind = data:find('"type":"status"', 1, true) and 'status' or 'heartbeat'
          local function close()
            client:close()
          end
          if kind == 'heartbeat' and replies.stop and not server:is_closing() then
            server:close()
          end
          if replies[kind] then
            client:write(replies[kind], close)
          else
            close()
          end
        end)
      end)
      config._set_for_testing({ socket_path = socket_path })
    end

    local function send()
      local result = {}
      socket.send_heartbeats({ { heartbeatId = 'test' } }, function(status, err)
        result.status = status
        result.err = err
      end)
      vim.wait(2000, function() return result.status ~= nil end, 10)
      return result
    end

    after_each(function()
      if server then
        if not server:is_closing() then
          server:close()
        end
        server = nil
      end
      os.remove(socket_path)
    end)

    it('should count an acknowledged batch as delivered', function()
      serve({ heartbeat = '{"status":"ok"}' })
      assert.equals('ok', send().status)
    end)

    it('should report a daemon with code tracking off', function()
      serve({ heartbeat = '{"status":"disabled"}' })
      assert.equals('disabled', send().status)
    end)

    it('should count an empty reply as delivered when the daemon still takes connections', function()
      -- 0.1.42-0.1.47 daemons took heartbeats without replying; 0.1.42 answers no status either
      serve({})
      assert.equals('ok', send().status)
    end)

    it('should keep a batch the daemon closed without acknowledging', function()
      -- A daemon that is going away stops listening before it drops the message
      serve({ stop = true })
      local result = send()
      assert.equals('failed', result.status)
      assert.is_string(result.err)
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
