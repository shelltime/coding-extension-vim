-- Language detection utilities for shelltime
-- Provides fallback language detection from file extension when filetype is empty

local M = {}

-- File extension to language mapping (used only when filetype is empty)
local extension_map = {
  lua = 'lua',
  py = 'python',
  js = 'javascript',
  ts = 'typescript',
  tsx = 'typescriptreact',
  jsx = 'javascriptreact',
  rs = 'rust',
  go = 'go',
  rb = 'ruby',
  php = 'php',
  java = 'java',
  kt = 'kotlin',
  swift = 'swift',
  c = 'c',
  cpp = 'cpp',
  cc = 'cpp',
  cxx = 'cpp',
  h = 'c',
  hpp = 'cpp',
  cs = 'csharp',
  txt = 'plaintext',
  sh = 'shellscript',
  bash = 'shellscript',
  zsh = 'shellscript',
  fish = 'fish',
  html = 'html',
  css = 'css',
  scss = 'scss',
  less = 'less',
  json = 'json',
  yaml = 'yaml',
  yml = 'yaml',
  xml = 'xml',
  md = 'markdown',
  sql = 'sql',
  vim = 'vim',
  dockerfile = 'dockerfile',
  toml = 'toml',
  ini = 'ini',
  conf = 'conf',
}

-- Neovim filetypes whose VS Code language id differs. The ShellTime plugins report
-- VS Code ids, which the web merges on, so a language isn't split across editors.
local filetype_ids = {
  sh = 'shellscript',
  bash = 'shellscript',
  zsh = 'shellscript',
  text = 'plaintext',
  make = 'makefile',
  cs = 'csharp',
  objc = 'objective-c',
  objcpp = 'objective-cpp',
  tex = 'latex',
  ps1 = 'powershell',
  ['javascript.jsx'] = 'javascriptreact',
  ['typescript.tsx'] = 'typescriptreact',
}

--- Get language for a file
---@param filetype string|nil Buffer filetype
---@param file_path string File path
---@return string Language identifier
function M.get_language(filetype, file_path)
  -- Use filetype if available
  if filetype and filetype ~= '' then
    return filetype_ids[filetype] or filetype
  end

  -- Fallback: detect from file extension
  local filename = file_path:match('[/\\]?([^/\\]+)$') or ''

  -- Check for hidden files without extension (e.g., .hidden, .gitignore)
  -- These start with a dot and have no other dots
  if filename:match('^%.[^%.]+$') then
    return ''
  end

  -- From the file name only: a dot in a directory (john.doe, .config) is no extension
  local ext = filename:match('%.([^%.]+)$')
  if ext then
    ext = ext:lower()
    return extension_map[ext] or ext
  end

  -- Special case: Dockerfile, Makefile, etc.
  local basename = filename:lower()
  if basename == 'dockerfile' then
    return 'dockerfile'
  elseif basename == 'makefile' then
    return 'makefile'
  end

  return ''
end

return M
