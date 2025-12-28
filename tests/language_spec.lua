-- Tests for shelltime/utils/language.lua
describe('shelltime.utils.language', function()
  local language

  before_each(function()
    package.loaded['shelltime.utils.language'] = nil
    language = require('shelltime.utils.language')
  end)

  describe('get_language', function()
    describe('when filetype is available', function()
      it('should return filetype as-is for lua', function()
        assert.equals('lua', language.get_language('lua', '/path/to/file.lua'))
      end)

      it('should return filetype as-is for python', function()
        assert.equals('python', language.get_language('python', '/path/to/file.py'))
      end)

      it('should return filetype as-is for typescript', function()
        assert.equals('typescript', language.get_language('typescript', '/path/to/file.ts'))
      end)

      it('should return filetype as-is for javascript', function()
        assert.equals('javascript', language.get_language('javascript', '/path/to/file.js'))
      end)

      it('should return filetype as-is for sh', function()
        assert.equals('sh', language.get_language('sh', '/path/to/file.sh'))
      end)

      it('should return filetype as-is for vim', function()
        assert.equals('vim', language.get_language('vim', '/path/to/file.vim'))
      end)

      it('should return filetype even if extension differs', function()
        assert.equals('python', language.get_language('python', '/path/to/file.txt'))
      end)
    end)

    describe('when filetype is empty', function()
      it('should detect lua from extension', function()
        assert.equals('lua', language.get_language('', '/path/to/file.lua'))
      end)

      it('should detect python from .py extension', function()
        assert.equals('python', language.get_language('', '/path/to/file.py'))
      end)

      it('should detect javascript from .js extension', function()
        assert.equals('javascript', language.get_language('', '/path/to/file.js'))
      end)

      it('should detect typescript from .ts extension', function()
        assert.equals('typescript', language.get_language('', '/path/to/file.ts'))
      end)

      it('should detect typescriptreact from .tsx extension', function()
        assert.equals('typescriptreact', language.get_language('', '/path/to/file.tsx'))
      end)

      it('should detect javascriptreact from .jsx extension', function()
        assert.equals('javascriptreact', language.get_language('', '/path/to/file.jsx'))
      end)

      it('should detect rust from .rs extension', function()
        assert.equals('rust', language.get_language('', '/path/to/file.rs'))
      end)

      it('should detect go from .go extension', function()
        assert.equals('go', language.get_language('', '/path/to/file.go'))
      end)

      it('should detect csharp from .cs extension', function()
        assert.equals('csharp', language.get_language('', '/path/to/file.cs'))
      end)

      it('should detect cpp from .cpp extension', function()
        assert.equals('cpp', language.get_language('', '/path/to/file.cpp'))
      end)

      it('should detect cpp from .cc extension', function()
        assert.equals('cpp', language.get_language('', '/path/to/file.cc'))
      end)

      it('should detect yaml from .yaml extension', function()
        assert.equals('yaml', language.get_language('', '/path/to/file.yaml'))
      end)

      it('should detect yaml from .yml extension', function()
        assert.equals('yaml', language.get_language('', '/path/to/file.yml'))
      end)

      it('should detect markdown from .md extension', function()
        assert.equals('markdown', language.get_language('', '/path/to/file.md'))
      end)

      it('should detect json from .json extension', function()
        assert.equals('json', language.get_language('', '/path/to/file.json'))
      end)

      it('should handle uppercase extensions', function()
        assert.equals('lua', language.get_language('', '/path/to/file.LUA'))
      end)

      it('should handle mixed case extensions', function()
        assert.equals('python', language.get_language('', '/path/to/file.Py'))
      end)

      it('should return unknown extension as-is', function()
        assert.equals('xyz', language.get_language('', '/path/to/file.xyz'))
      end)
    end)

    describe('special filenames', function()
      it('should detect dockerfile', function()
        assert.equals('dockerfile', language.get_language('', '/path/to/Dockerfile'))
      end)

      it('should detect dockerfile case insensitive', function()
        assert.equals('dockerfile', language.get_language('', '/path/to/dockerfile'))
      end)

      it('should detect makefile', function()
        assert.equals('makefile', language.get_language('', '/path/to/Makefile'))
      end)

      it('should detect makefile case insensitive', function()
        assert.equals('makefile', language.get_language('', '/path/to/makefile'))
      end)
    end)

    describe('edge cases', function()
      it('should return empty string for nil filetype and no extension', function()
        assert.equals('', language.get_language(nil, '/path/to/file'))
      end)

      it('should return empty string for empty filetype and no extension', function()
        assert.equals('', language.get_language('', '/path/to/file'))
      end)

      it('should handle file with multiple dots', function()
        assert.equals('lua', language.get_language('', '/path/to/file.test.lua'))
      end)

      it('should handle hidden files with extension', function()
        assert.equals('yaml', language.get_language('', '/path/to/.hidden.yaml'))
      end)

      it('should return empty for hidden files without extension', function()
        assert.equals('', language.get_language('', '/path/to/.hidden'))
      end)

      it('should handle nil filetype', function()
        assert.equals('lua', language.get_language(nil, '/path/to/file.lua'))
      end)

      it('should prefer filetype over extension', function()
        assert.equals('typescriptreact', language.get_language('typescriptreact', '/path/to/file.tsx'))
      end)
    end)
  end)
end)
