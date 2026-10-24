-- Tests for shelltime/utils/git.lua
describe('shelltime.utils.git', function()
  local git
  local helpers

  before_each(function()
    package.loaded['shelltime.utils.git'] = nil
    git = require('shelltime.utils.git')
    helpers = require('tests.helpers')
  end)

  describe('get_branch', function()
    it('should return branch name for file in git repo', function()
      local project_dir = helpers.get_project_dir()
      local test_file = project_dir .. '/lua/shelltime/init.lua'
      local branch = git.get_branch(test_file)

      assert.is_string(branch)
      assert.is_true(#branch > 0)
    end)

    it('should return empty string for non-git directory', function()
      local branch = git.get_branch('/tmp/not-a-git-repo/file.lua')
      assert.equals('', branch)
    end)

    it('should return empty string for non-existent directory', function()
      local branch = git.get_branch('/nonexistent/path/file.lua')
      assert.equals('', branch)
    end)

    it('should trim whitespace from branch name', function()
      local project_dir = helpers.get_project_dir()
      local test_file = project_dir .. '/lua/shelltime/init.lua'
      local branch = git.get_branch(test_file)

      assert.equals(branch, vim.trim(branch))
    end)

    it('should handle nested files in git repo', function()
      local project_dir = helpers.get_project_dir()
      local nested_file = project_dir .. '/lua/shelltime/utils/yaml.lua'
      local branch = git.get_branch(nested_file)

      assert.is_string(branch)
      assert.is_true(#branch > 0)
    end)

    it('should return same branch for files in same repo', function()
      local project_dir = helpers.get_project_dir()
      local file1 = project_dir .. '/lua/shelltime/init.lua'
      local file2 = project_dir .. '/lua/shelltime/config.lua'

      local branch1 = git.get_branch(file1)
      local branch2 = git.get_branch(file2)

      assert.equals(branch1, branch2)
    end)

    it('should handle root level files', function()
      local project_dir = helpers.get_project_dir()
      -- Use a file at root level if it exists
      local root_file = project_dir .. '/README.md'
      if vim.fn.filereadable(root_file) == 1 then
        local branch = git.get_branch(root_file)
        assert.is_string(branch)
      end
    end)

    describe('reftable repositories', function()
      -- git's reftable backend keeps the real HEAD in reftable/ and writes a stub to HEAD
      local spy = require('luassert.spy')
      local stub = require('luassert.stub')
      local dir
      local system

      local function git_in(repo, ...)
        vim.fn.system(vim.list_extend({ 'git', '-C', repo, '-c', 'user.name=t', '-c', 'user.email=t@t' }, { ... }))
        assert.equals(0, vim.v.shell_error)
      end

      before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir .. '/src', 'p')
      end)

      after_each(function()
        if system then
          system:revert()
          system = nil
        end
        vim.fn.delete(dir, 'rf')
      end)

      it('should ask git, once per repository, when the git directory has reftable/', function()
        git_in(dir, 'init', '-q')
        git_in(dir, 'commit', '-q', '--allow-empty', '-m', 'init')
        git_in(dir, 'checkout', '-q', '-b', 'feature/reftable')
        vim.fn.mkdir(dir .. '/.git/reftable', 'p')
        system = spy.on(vim, 'system')

        assert.equals('feature/reftable', git.get_branch(dir .. '/a.lua'))
        assert.equals('feature/reftable', git.get_branch(dir .. '/src/b.lua'))
        assert.spy(system).was_called(1)
      end)

      it('should report no branch when git fails for a HEAD stub', function()
        vim.fn.mkdir(dir .. '/.git/reftable', 'p')
        vim.fn.writefile({ 'ref: refs/heads/.invalid' }, dir .. '/.git/HEAD')

        assert.equals('', git.get_branch(dir .. '/a.lua'))
      end)

      it('should report no branch when git is not installed', function()
        vim.fn.mkdir(dir .. '/.git', 'p')
        vim.fn.writefile({ 'ref: refs/heads/.invalid' }, dir .. '/.git/HEAD')
        system = stub(vim, 'system')
        system.invokes(function()
          error('ENOENT: no such file or directory (cmd): git')
        end)

        assert.equals('', git.get_branch(dir .. '/a.lua'))
      end)

      it('should not run git for a repository whose HEAD names the branch', function()
        vim.fn.mkdir(dir .. '/.git', 'p')
        vim.fn.writefile({ 'ref: refs/heads/main' }, dir .. '/.git/HEAD')
        system = spy.on(vim, 'system')

        assert.equals('main', git.get_branch(dir .. '/a.lua'))
        assert.spy(system).was_not_called()
      end)
    end)

    it('should not contain newlines', function()
      local project_dir = helpers.get_project_dir()
      local test_file = project_dir .. '/lua/shelltime/init.lua'
      local branch = git.get_branch(test_file)

      assert.is_nil(branch:match('\n'))
      assert.is_nil(branch:match('\r'))
    end)
  end)
end)
