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

    it('should not contain newlines', function()
      local project_dir = helpers.get_project_dir()
      local test_file = project_dir .. '/lua/shelltime/init.lua'
      local branch = git.get_branch(test_file)

      assert.is_nil(branch:match('\n'))
      assert.is_nil(branch:match('\r'))
    end)
  end)
end)
