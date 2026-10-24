-- Git utilities for shelltime

local M = {}

-- How long a branch git printed is used before git is asked again
local BRANCH_CACHE_MS = 30000

-- Branches git printed, per git directory, for repositories whose HEAD file
-- doesn't name the branch
local branch_cache = {}

--- Find the git directory for a file's directory: the nearest .git directory,
--- or where a worktree's or submodule's .git file points
---@param dir string Directory to start from
---@return string|nil Git directory
local function find_git_dir(dir)
  local path = dir
  while path and path ~= '' do
    local dot_git = path .. '/.git'
    if vim.fn.isdirectory(dot_git) == 1 then
      return dot_git
    end
    if vim.fn.filereadable(dot_git) == 1 then
      local ok, lines = pcall(vim.fn.readfile, dot_git, '', 1)
      local gitdir = ok and lines[1] and lines[1]:match('^gitdir:%s*(.-)%s*$')
      if gitdir then
        if gitdir:sub(1, 1) ~= '/' then
          gitdir = path .. '/' .. gitdir
        end
        return vim.fn.fnamemodify(gitdir, ':p'):gsub('/$', '')
      end
    end
    local parent = vim.fn.fnamemodify(path, ':h')
    if parent == path then
      break
    end
    path = parent
  end
  return nil
end

--- The branch git itself reports for a directory, at most once per git
--- directory every BRANCH_CACHE_MS, or '' when git fails
---@param dir string Directory in the repository
---@param git_dir string Its git directory
---@return string Branch name or empty string
local function branch_from_git(dir, git_dir)
  local now = (vim.uv or vim.loop).now()
  local cached = branch_cache[git_dir]
  if cached and now - cached.at < BRANCH_CACHE_MS then
    return cached.branch
  end

  local branch = ''
  -- It raises an error when git isn't installed, and git fails outside a repository
  local ok, lines = pcall(vim.fn.systemlist, { 'git', '-C', dir, 'rev-parse', '--abbrev-ref', 'HEAD' })
  if ok and vim.v.shell_error == 0 and #lines > 0 then
    -- The output includes git's warnings, which come before the branch
    branch = vim.trim(lines[#lines])
  end
  branch_cache[git_dir] = { branch = branch, at = now }
  return branch
end

--- Get current git branch for a file, as `git rev-parse --abbrev-ref HEAD`
--- prints it ('HEAD' when detached). It reads HEAD instead of running git,
--- which blocked the editor on every heartbeat. A reftable repository keeps
--- its real HEAD in reftable/ and leaves a `ref: refs/heads/.invalid` stub,
--- so only there git is asked, and its answer cached.
---@param file_path string File path
---@return string Branch name or empty string
function M.get_branch(file_path)
  local dir = vim.fn.fnamemodify(file_path, ':p:h')

  -- Check if directory exists
  if vim.fn.isdirectory(dir) ~= 1 then
    return ''
  end

  local git_dir = find_git_dir(dir)
  if not git_dir then
    return ''
  end

  local ok, lines = pcall(vim.fn.readfile, git_dir .. '/HEAD', '', 1)
  if not ok or not lines[1] then
    return ''
  end

  local branch = lines[1]:match('^ref:%s*refs/heads/(.-)%s*$')
  if branch == '.invalid' or vim.fn.isdirectory(git_dir .. '/reftable') == 1 then
    return branch_from_git(dir, git_dir)
  end
  return branch or 'HEAD'
end

return M
