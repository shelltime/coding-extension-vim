-- Tests for shelltime/version.lua
describe('shelltime.version', function()
  local version
  local config
  local stub = require('luassert.stub')
  local stubs = {}

  -- Helper to create and track stubs
  local function create_stub(obj, method)
    local s = stub(obj, method)
    table.insert(stubs, s)
    return s
  end

  before_each(function()
    -- Reset modules
    package.loaded['shelltime.version'] = nil
    package.loaded['shelltime.config'] = nil

    config = require('shelltime.config')
    config.setup({ config = '/nonexistent/config.yaml' })
    version = require('shelltime.version')
  end)

  after_each(function()
    -- Revert all stubs
    for _, s in ipairs(stubs) do
      if s and s.revert then
        s:revert()
      end
    end
    stubs = {}
  end)

  describe('check_version', function()
    describe('configuration handling', function()
      it('should skip when no API endpoint configured', function()
        local called = false
        local error_msg = nil

        version.check_version('1.0.0', function(result, err)
          called = true
          error_msg = err
        end)

        assert.is_true(called)
        assert.is_nil(nil)
        assert.equals('No endpoint configured', error_msg)
      end)

      it('should not crash without callback when no endpoint', function()
        assert.has_no_errors(function()
          version.check_version('1.0.0')
        end)
      end)
    end)

    describe('API call construction', function()
      local jobstart_stub
      local captured_cmd
      local captured_opts

      before_each(function()
        -- Configure endpoints
        package.loaded['shelltime.config'] = nil
        config = require('shelltime.config')
        config._set_for_testing({
          api_endpoint = 'https://api.example.com',
          web_endpoint = 'https://example.com',
        })
        package.loaded['shelltime.version'] = nil
        version = require('shelltime.version')

        jobstart_stub = create_stub(vim.fn, 'jobstart')
        jobstart_stub.invokes(function(cmd, opts)
          captured_cmd = cmd
          captured_opts = opts
          return 1
        end)
      end)

      it('should call curl with correct command', function()
        version.check_version('1.0.0', function() end)

        assert.is_table(captured_cmd)
        assert.equals('curl', captured_cmd[1])
      end)

      it('should include timeout flag', function()
        version.check_version('1.0.0', function() end)

        local has_timeout = false
        for i, arg in ipairs(captured_cmd) do
          if arg == '-m' and captured_cmd[i + 1] == '5' then
            has_timeout = true
            break
          end
        end
        assert.is_true(has_timeout)
      end)

      it('should include Accept header', function()
        version.check_version('1.0.0', function() end)

        local has_accept_header = false
        for i, arg in ipairs(captured_cmd) do
          if arg == '-H' and captured_cmd[i + 1] == 'Accept: application/json' then
            has_accept_header = true
            break
          end
        end
        assert.is_true(has_accept_header)
      end)

      it('should include version parameter in URL', function()
        version.check_version('1.2.3', function() end)

        local url = captured_cmd[#captured_cmd]
        assert.matches('version=1%.2%.3', url)
      end)

      it('should URL encode version with special characters', function()
        version.check_version('1.0.0-beta+build', function() end)

        local url = captured_cmd[#captured_cmd]
        -- + should be encoded as %2B
        assert.matches('%%2B', url)
      end)

      it('should use configured API endpoint', function()
        version.check_version('1.0.0', function() end)

        local url = captured_cmd[#captured_cmd]
        assert.matches('^https://api%.example%.com', url)
      end)

      it('should include version check endpoint path', function()
        version.check_version('1.0.0', function() end)

        local url = captured_cmd[#captured_cmd]
        assert.matches('/api/v1/cli/version%-check', url)
      end)
    end)

    describe('success responses', function()
      local jobstart_stub
      local notify_stub

      before_each(function()
        -- Configure endpoints
        package.loaded['shelltime.config'] = nil
        config = require('shelltime.config')
        config._set_for_testing({
          api_endpoint = 'https://api.example.com',
          web_endpoint = 'https://example.com',
        })
        package.loaded['shelltime.version'] = nil
        version = require('shelltime.version')

        notify_stub = create_stub(vim, 'notify')
      end)

      after_each(function()
        if jobstart_stub and jobstart_stub.revert then
          jobstart_stub:revert()
        end
      end)

      it('should not show warning when version is latest', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '{"isLatest":true}' })
          opts.on_exit(1, 0)
          return 1
        end)

        local called = false
        local result_data = nil
        version.check_version('1.0.0', function(result, err)
          called = true
          result_data = result
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        assert.is_table(result_data)
        assert.is_true(result_data.isLatest)
        -- Should not have called vim.notify with WARN level
        for _, call in ipairs(notify_stub.calls or {}) do
          if call.refs and call.refs[2] == vim.log.levels.WARN then
            assert.fail('Should not show warning when version is latest')
          end
        end
      end)

      it('should show warning when update available', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '{"isLatest":false,"latestVersion":"2.0.0"}' })
          opts.on_exit(1, 0)
          return 1
        end)

        local called = false
        version.check_version('1.0.0', function(result, err)
          called = true
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        -- Check that vim.notify was called with WARN level
        local warn_called = false
        for _, call in ipairs(notify_stub.calls or {}) do
          if call.refs and call.refs[2] == vim.log.levels.WARN then
            warn_called = true
            local message = call.refs[1]
            assert.matches('1%.0%.0', message)
            assert.matches('2%.0%.0', message)
          end
        end
        assert.is_true(warn_called)
      end)

      it('should return result with latestVersion', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '{"isLatest":false,"latestVersion":"2.0.0"}' })
          opts.on_exit(1, 0)
          return 1
        end)

        local result_data = nil
        local called = false
        version.check_version('1.0.0', function(result, err)
          called = true
          result_data = result
        end)

        vim.wait(100, function() return called end)

        assert.is_table(result_data)
        assert.is_false(result_data.isLatest)
        assert.equals('2.0.0', result_data.latestVersion)
      end)

      it('should handle multiline JSON response', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          -- Simulate response split across multiple lines
          opts.on_stdout(1, { '{"isLatest":', 'true}' })
          opts.on_exit(1, 0)
          return 1
        end)

        local called = false
        local result_data = nil
        version.check_version('1.0.0', function(result, err)
          called = true
          result_data = result
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        assert.is_table(result_data)
        assert.is_true(result_data.isLatest)
      end)
    end)

    describe('error handling', function()
      local jobstart_stub

      before_each(function()
        -- Configure endpoints
        package.loaded['shelltime.config'] = nil
        config = require('shelltime.config')
        config._set_for_testing({
          api_endpoint = 'https://api.example.com',
          web_endpoint = 'https://example.com',
        })
        package.loaded['shelltime.version'] = nil
        version = require('shelltime.version')
      end)

      it('should handle curl failure with non-zero exit code', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_exit(1, 7) -- curl exit code 7 = connection refused
          return 1
        end)

        local called = false
        local error_msg = nil
        version.check_version('1.0.0', function(result, err)
          called = true
          error_msg = err
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        assert.equals('curl failed', error_msg)
      end)

      it('should handle invalid JSON response', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { 'not valid json' })
          opts.on_exit(1, 0)
          return 1
        end)

        local called = false
        local error_msg = nil
        version.check_version('1.0.0', function(result, err)
          called = true
          error_msg = err
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        assert.equals('Parse error', error_msg)
      end)

      it('should handle empty response', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '' })
          opts.on_exit(1, 0)
          return 1
        end)

        local called = false
        local error_msg = nil
        version.check_version('1.0.0', function(result, err)
          called = true
          error_msg = err
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        assert.equals('Parse error', error_msg)
      end)

      it('should handle HTML error response', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '<html><body>500 Internal Server Error</body></html>' })
          opts.on_exit(1, 0)
          return 1
        end)

        local called = false
        local error_msg = nil
        version.check_version('1.0.0', function(result, err)
          called = true
          error_msg = err
        end)

        vim.wait(100, function() return called end)

        assert.is_true(called)
        assert.equals('Parse error', error_msg)
      end)

      it('should work without callback on error', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_exit(1, 1)
          return 1
        end)

        assert.has_no_errors(function()
          version.check_version('1.0.0')
        end)
      end)
    end)

    describe('session state', function()
      local jobstart_stub
      local notify_stub

      before_each(function()
        -- Configure endpoints
        package.loaded['shelltime.config'] = nil
        config = require('shelltime.config')
        config._set_for_testing({
          api_endpoint = 'https://api.example.com',
          web_endpoint = 'https://example.com',
        })
        package.loaded['shelltime.version'] = nil
        version = require('shelltime.version')

        notify_stub = create_stub(vim, 'notify')
      end)

      it('should only show warning once per session', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '{"isLatest":false,"latestVersion":"2.0.0"}' })
          opts.on_exit(1, 0)
          return 1
        end)

        -- First call
        local first_called = false
        version.check_version('1.0.0', function(result, err)
          first_called = true
        end)
        vim.wait(100, function() return first_called end)

        -- Count warn notifications
        local warn_count_after_first = 0
        for _, call in ipairs(notify_stub.calls or {}) do
          if call.refs and call.refs[2] == vim.log.levels.WARN then
            warn_count_after_first = warn_count_after_first + 1
          end
        end

        -- Second call should skip
        local second_called = false
        local second_error = nil
        version.check_version('1.0.0', function(result, err)
          second_called = true
          second_error = err
        end)

        assert.is_true(second_called)
        assert.equals('Already shown', second_error)

        -- Warn count should not increase
        local warn_count_after_second = 0
        for _, call in ipairs(notify_stub.calls or {}) do
          if call.refs and call.refs[2] == vim.log.levels.WARN then
            warn_count_after_second = warn_count_after_second + 1
          end
        end

        assert.equals(warn_count_after_first, warn_count_after_second)
      end)

      it('should reset warning state on module reload', function()
        jobstart_stub = stub(vim.fn, 'jobstart')
        table.insert(stubs, jobstart_stub)
        jobstart_stub.invokes(function(cmd, opts)
          opts.on_stdout(1, { '{"isLatest":false,"latestVersion":"2.0.0"}' })
          opts.on_exit(1, 0)
          return 1
        end)

        -- First call shows warning
        local first_called = false
        version.check_version('1.0.0', function(result, err)
          first_called = true
        end)
        vim.wait(100, function() return first_called end)

        -- Reload module
        package.loaded['shelltime.version'] = nil
        version = require('shelltime.version')

        -- Should make API call again (not return 'Already shown')
        local second_called = false
        local second_error = nil
        version.check_version('1.0.0', function(result, err)
          second_called = true
          second_error = err
        end)

        vim.wait(100, function() return second_called end)

        -- Should not be 'Already shown' error since module was reloaded
        assert.is_not.equals('Already shown', second_error)
      end)
    end)
  end)

  describe('show_update_warning', function()
    local notify_stub
    local has_stub
    local setreg_stub

    before_each(function()
      -- Configure web endpoint
      package.loaded['shelltime.config'] = nil
      config = require('shelltime.config')
      config._set_for_testing({
        web_endpoint = 'https://example.com',
      })

      notify_stub = create_stub(vim, 'notify')
    end)

    it('should show warning notification', function()
      version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')

      assert.stub(notify_stub).was_called()
    end)

    it('should include current and latest version in message', function()
      version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')

      local message = notify_stub.calls[1].refs[1]
      assert.matches('1%.0%.0', message)
      assert.matches('2%.0%.0', message)
    end)

    it('should include update command in message', function()
      version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')

      local message = notify_stub.calls[1].refs[1]
      assert.matches('curl %-sSL https://example%.com/i | bash', message)
    end)

    it('should use WARN log level', function()
      version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')

      local level = notify_stub.calls[1].refs[2]
      assert.equals(vim.log.levels.WARN, level)
    end)

    it('should copy to clipboard when available', function()
      has_stub = create_stub(vim.fn, 'has')
      has_stub.returns(1)
      setreg_stub = create_stub(vim.fn, 'setreg')

      version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')

      assert.stub(setreg_stub).was_called()
      local reg = setreg_stub.calls[1].refs[1]
      local content = setreg_stub.calls[1].refs[2]
      assert.equals('+', reg)
      assert.matches('curl %-sSL https://example%.com/i | bash', content)
    end)

    it('should not crash when clipboard unavailable', function()
      has_stub = create_stub(vim.fn, 'has')
      has_stub.returns(0)

      assert.has_no_errors(function()
        version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')
      end)
    end)

    it('should notify about clipboard copy', function()
      has_stub = create_stub(vim.fn, 'has')
      has_stub.returns(1)
      setreg_stub = create_stub(vim.fn, 'setreg')

      version.show_update_warning('1.0.0', '2.0.0', 'https://example.com')

      -- Should have two notifications: warning and clipboard info
      assert.equals(2, #notify_stub.calls)
      local info_message = notify_stub.calls[2].refs[1]
      local info_level = notify_stub.calls[2].refs[2]
      assert.matches('clipboard', info_message)
      assert.equals(vim.log.levels.INFO, info_level)
    end)
  end)

  describe('module exports', function()
    it('should export check_version function', function()
      assert.is_function(version.check_version)
    end)

    it('should export show_update_warning function', function()
      assert.is_function(version.show_update_warning)
    end)
  end)
end)
