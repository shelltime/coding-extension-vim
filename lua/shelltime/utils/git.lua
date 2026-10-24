-- Git utilities for shelltime

local M = {}

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

--- Get current git branch for a file, as `git rev-parse --abbrev-ref HEAD`
--- prints it ('HEAD' when detached). It reads HEAD instead of running git,
--- which blocked the editor on every heartbeat.
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

  return lines[1]:match('^ref:%s*refs/heads/(.-)%s*$') or 'HEAD'
end

return M
