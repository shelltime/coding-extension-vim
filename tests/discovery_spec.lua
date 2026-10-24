-- Config discovery, project roots and branches against real files in a temp HOME
describe('shelltime file discovery', function()
  local stub = require('luassert.stub')
  local tmp
  local original_home

  local function write(rel, content)
    local path = tmp .. '/' .. rel
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    vim.fn.writefile(vim.split(content, '\n'), path)
    return path
  end

  before_each(function()
    tmp = vim.fn.resolve(vim.fn.tempname())
    vim.fn.mkdir(tmp, 'p')
    original_home = vim.env.HOME
    vim.env.HOME = tmp
    package.loaded['shelltime.config'] = nil
    package.loaded['shelltime.utils.system'] = nil
    package.loaded['shelltime.utils.git'] = nil
  end)

  after_each(function()
    vim.env.HOME = original_home
    vim.fn.delete(tmp, 'rf')
  end)

  describe('config without a config option', function()
    it('should read config.yaml, which shelltime init writes', function()
      write('.shelltime/config.yaml', 'socketPath: /tmp/yaml.sock\ncodeTracking:\n  enabled: false # off for now')
      local config = require('shelltime.config')
      config.setup()

      assert.equals('/tmp/yaml.sock', config.get('socket_path'))
      assert.is_false(config.is_enabled())
    end)

    it('should prefer config.yaml over config.yml and config.toml, like the CLI', function()
      write('.shelltime/config.toml', 'socketPath = "/tmp/toml.sock"')
      write('.shelltime/config.yml', 'socketPath: /tmp/yml.sock')
      local config = require('shelltime.config')

      config.setup()
      assert.equals('/tmp/yml.sock', config.get('socket_path'))
      assert.equals('~/.shelltime/config.yml', config.get_config_path())

      vim.fn.delete(tmp .. '/.shelltime/config.yml')
      config.setup()
      assert.equals('/tmp/toml.sock', config.get('socket_path'))
      assert.equals('~/.shelltime/config.toml', config.get_config_path())
    end)

    it('should read the CLI TOML keys', function()
      write('.shelltime/config.toml', 'APIEndpoint = "http://localhost:27312"\n[codeTracking]\nenabled = true')
      local config = require('shelltime.config')
      config.setup()

      assert.equals('http://localhost:27312', config.get('api_endpoint'))
      assert.is_true(config.is_enabled())
    end)

    it('should merge config.local.* over the base file', function()
      write('.shelltime/config.yaml', 'socketPath: /tmp/base.sock\nwebEndpoint: https://shelltime.xyz\ncodeTracking:\n  enabled: false')
      write('.shelltime/config.local.yaml', 'socketPath: /tmp/local.sock\ncodeTracking:\n  enabled: true')
      local config = require('shelltime.config')
      config.setup()

      assert.equals('/tmp/local.sock', config.get('socket_path'))
      assert.equals('https://shelltime.xyz', config.get('web_endpoint'))
      assert.is_true(config.is_enabled())
    end)

    it('should keep tracking enabled when the local file only sets the token', function()
      write('.shelltime/config.yaml', 'codeTracking:\n  enabled: true')
      write('.shelltime/config.local.yaml', 'codeTracking:\n  token: secret')
      local config = require('shelltime.config')
      config.setup()

      assert.is_true(config.is_enabled())
    end)

    it('should use the defaults without any config file', function()
      local config = require('shelltime.config')
      config.setup()

      assert.equals('/tmp/shelltime.sock', config.get('socket_path'))
      assert.is_true(config.is_enabled())
    end)

    it('should not look at the files on every call', function()
      write('.shelltime/config.yaml', 'socketPath: /tmp/first.sock')
      local config = require('shelltime.config')
      config.setup()
      assert.equals('/tmp/first.sock', config.get('socket_path'))

      local stat_stub = stub(vim.loop, 'fs_stat')
      for _ = 1, 100 do
        config.get('socket_path')
      end
      assert.stub(stat_stub).was_called(0)
      stat_stub:revert()
    end)
  end)

  describe('project root', function()
    it('should be the repository, not a nested package', function()
      write('mono/.git/HEAD', 'ref: refs/heads/main')
      write('mono/packages/ui/package.json', '{}')
      local file = write('mono/packages/ui/src/Button.tsx', '')
      local system = require('shelltime.utils.system')

      local root = system.get_project_root(file)
      assert.equals(tmp .. '/mono', root)
      assert.equals(vim.fn.fnamemodify(tmp, ':t') .. '/mono', system.get_project_name(root))
    end)

    it('should fall back to the nearest marker outside a repository', function()
      write('plain/app/package.json', '{}')
      local file = write('plain/app/src/index.js', '')

      assert.equals(tmp .. '/plain/app', require('shelltime.utils.system').get_project_root(file))
    end)
  end)

  describe('branch', function()
    it('should read the branch from HEAD', function()
      write('repo/.git/HEAD', 'ref: refs/heads/feature/x')
      local file = write('repo/src/main.go', '')

      assert.equals('feature/x', require('shelltime.utils.git').get_branch(file))
    end)

    it('should report HEAD when detached', function()
      write('repo/.git/HEAD', '3f2c1b0e9d8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e')
      local file = write('repo/main.go', '')

      assert.equals('HEAD', require('shelltime.utils.git').get_branch(file))
    end)

    it('should follow a relative gitdir, as submodules use', function()
      write('super/.git/HEAD', 'ref: refs/heads/main')
      write('super/.git/modules/lib/HEAD', 'ref: refs/heads/lib-branch')
      write('super/lib/.git', 'gitdir: ../.git/modules/lib')
      local file = write('super/lib/init.lua', '')

      assert.equals('lib-branch', require('shelltime.utils.git').get_branch(file))
    end)
  end)
end)
