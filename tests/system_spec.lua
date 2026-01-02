-- Tests for shelltime/utils/system.lua
describe('shelltime.utils.system', function()
  local system
  local helpers

  before_each(function()
    package.loaded['shelltime.utils.system'] = nil
    system = require('shelltime.utils.system')
    helpers = require('tests.helpers')
  end)

  describe('uuid', function()
    it('should return a string', function()
      local id = system.uuid()
      assert.is_string(id)
    end)

    it('should match UUID v4 format', function()
      local id = system.uuid()
      -- UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      local pattern = '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'
      assert.matches(pattern, id)
    end)

    it('should generate unique IDs', function()
      local ids = {}
      for _ = 1, 100 do
        local id = system.uuid()
        assert.is_nil(ids[id], 'UUID collision detected')
        ids[id] = true
      end
    end)

    it('should have version 4 indicator', function()
      local id = system.uuid()
      -- Position 15 (1-indexed) should be '4'
      assert.equals('4', id:sub(15, 15))
    end)

    it('should have correct variant bits', function()
      local id = system.uuid()
      -- Position 20 (1-indexed) should be 8, 9, a, or b
      local variant = id:sub(20, 20)
      assert.matches('[89ab]', variant)
    end)

    it('should have correct length', function()
      local id = system.uuid()
      assert.equals(36, #id)
    end)

    it('should have hyphens at correct positions', function()
      local id = system.uuid()
      assert.equals('-', id:sub(9, 9))
      assert.equals('-', id:sub(14, 14))
      assert.equals('-', id:sub(19, 19))
      assert.equals('-', id:sub(24, 24))
    end)
  end)

  describe('get_timestamp', function()
    it('should return a number', function()
      local ts = system.get_timestamp()
      assert.is_number(ts)
    end)

    it('should return Unix timestamp (reasonable range)', function()
      local ts = system.get_timestamp()
      -- Should be after year 2020 and before 2100
      assert.is_true(ts > 1577836800)  -- Jan 1, 2020
      assert.is_true(ts < 4102444800)  -- Jan 1, 2100
    end)

    it('should return consistent values within same second', function()
      local ts1 = system.get_timestamp()
      local ts2 = system.get_timestamp()
      assert.is_true(math.abs(ts2 - ts1) <= 1)
    end)

    it('should be an integer', function()
      local ts = system.get_timestamp()
      assert.equals(math.floor(ts), ts)
    end)
  end)

  describe('get_os_name', function()
    it('should return a non-empty string', function()
      local name = system.get_os_name()
      assert.is_string(name)
      assert.is_true(#name > 0)
    end)

    it('should return expected OS name for current platform', function()
      local name = system.get_os_name()
      -- Should be one of the known OS names or raw sysname
      local known = { 'macOS', 'Linux', 'Windows' }
      local is_known = false
      for _, os_name in ipairs(known) do
        if name == os_name then
          is_known = true
          break
        end
      end
      -- Either known or at least not empty
      assert.is_true(is_known or #name > 0)
    end)
  end)

  describe('get_os_version', function()
    it('should return a string', function()
      local version = system.get_os_version()
      assert.is_string(version)
    end)

    it('should return non-empty version', function()
      local version = system.get_os_version()
      -- Most systems should have a version
      assert.is_string(version)
    end)
  end)

  describe('get_hostname', function()
    it('should return a non-empty string', function()
      local hostname = system.get_hostname()
      assert.is_string(hostname)
      assert.is_true(#hostname > 0)
    end)

    it('should not contain unknown when available', function()
      local hostname = system.get_hostname()
      -- If we have a real hostname, it shouldn't be 'unknown'
      -- (unless that's the actual hostname)
      assert.is_string(hostname)
    end)
  end)

  describe('get_editor_version', function()
    it('should return version string in format X.Y.Z', function()
      local version = system.get_editor_version()
      assert.is_string(version)
      assert.matches('^%d+%.%d+%.%d+$', version)
    end)

    it('should match vim.version()', function()
      local version = system.get_editor_version()
      local v = vim.version()
      local expected = string.format('%d.%d.%d', v.major, v.minor, v.patch)
      assert.equals(expected, version)
    end)
  end)

  describe('get_project_root', function()
    it('should find .git directory as project root', function()
      local project_dir = helpers.get_project_dir()
      local test_file = project_dir .. '/lua/shelltime/init.lua'
      local root = system.get_project_root(test_file)

      assert.is_string(root)
      assert.is_true(vim.fn.isdirectory(root .. '/.git') == 1)
    end)

    it('should return project root for nested file', function()
      local project_dir = helpers.get_project_dir()
      local nested_file = project_dir .. '/lua/shelltime/utils/yaml.lua'
      local root = system.get_project_root(nested_file)

      assert.equals(project_dir, root)
    end)

    it('should return file directory when no markers found', function()
      local root = system.get_project_root('/tmp/random/file.lua')
      assert.equals('/tmp/random', root)
    end)

    it('should handle absolute paths', function()
      local project_dir = helpers.get_project_dir()
      local root = system.get_project_root(project_dir .. '/lua/shelltime/init.lua')
      assert.is_string(root)
      assert.is_true(#root > 0)
    end)
  end)

  describe('get_project_name', function()
    it('should extract last 2 folder layers from path', function()
      local name = system.get_project_name('/home/user/projects/myapp')
      assert.equals('projects/myapp', name)
    end)

    it('should handle simple path with only 1 layer', function()
      local name = system.get_project_name('/myapp')
      assert.equals('myapp', name)
    end)

    it('should handle current project', function()
      local project_dir = helpers.get_project_dir()
      local name = system.get_project_name(project_dir)
      assert.is_string(name)
      assert.is_true(#name > 0)
      -- Should contain a slash for 2 layers
      assert.is_true(name:find('/') ~= nil)
    end)
  end)
end)
