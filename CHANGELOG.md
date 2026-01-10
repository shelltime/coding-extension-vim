# Changelog

## [0.0.4](https://github.com/shelltime/coding-extension-vim/compare/v0.0.3...v0.0.4) (2026-01-08)


### Features

* **version:** add CLI version check on extension startup ([4cd3920](https://github.com/shelltime/coding-extension-vim/commit/4cd3920e7ff021424a6258fcdf06097da6ccc220))
* **version:** add CLI version check on extension startup ([74db5fb](https://github.com/shelltime/coding-extension-vim/commit/74db5fb1277c78c4c8184c60a94c2e0ba1f04591))


### Code Refactoring

* **version:** use vim.json.decode for JSON parsing ([ed461c7](https://github.com/shelltime/coding-extension-vim/commit/ed461c794b2baaeebd14e4c189b1e2dac7aff338))


### Tests

* **version:** add comprehensive tests for version checker module ([fc67b4a](https://github.com/shelltime/coding-extension-vim/commit/fc67b4ac1b84bf788a6c3113b3788c48e20caf9e))

## [0.0.3](https://github.com/shelltime/coding-extension-vim/compare/v0.0.2...v0.0.3) (2026-01-03)


### Features

* **heartbeat:** skip duplicate activity events ([57a969e](https://github.com/shelltime/coding-extension-vim/commit/57a969e6a7388ef08348868283d2dc7bd164acf0))


### Bug Fixes

* **heartbeat:** correct order of debounce and duplicate checks ([fb4bc6b](https://github.com/shelltime/coding-extension-vim/commit/fb4bc6bba5adfcc2dc0382fd9a3c9597aa591d13))
* **heartbeat:** update last_activity before debounce check ([4ee3787](https://github.com/shelltime/coding-extension-vim/commit/4ee378798897714d7cf59d24a28592ba028c289e))

## [0.0.2](https://github.com/shelltime/coding-extension-vim/compare/v0.0.1...v0.0.2) (2026-01-02)


### Features

* **ci:** add GitHub Actions workflow with code coverage ([4fa8be1](https://github.com/shelltime/coding-extension-vim/commit/4fa8be1935bcf7fde181c4eded91d7eea9a8e73d))
* **ci:** add GitHub Actions workflow with code coverage ([56046a6](https://github.com/shelltime/coding-extension-vim/commit/56046a64ddbf8f09fb8b6a075666972e9e00b544))
* **plugin:** implement shelltime.nvim coding activity tracker ([859a12c](https://github.com/shelltime/coding-extension-vim/commit/859a12cf7207b354d6ed735acfcbe58cc4c0f4d1))
* **system:** use last 2 folder layers for project name ([e00de0a](https://github.com/shelltime/coding-extension-vim/commit/e00de0ad966310cddf9b07fd499c16a7d1f31a23))
* **system:** use last 2 folder layers for project name ([c1e1815](https://github.com/shelltime/coding-extension-vim/commit/c1e1815fd5b296171ab347cbd49973c87c7f201a))
* **tests:** add comprehensive test suite with plenary.nvim ([9bb7ace](https://github.com/shelltime/coding-extension-vim/commit/9bb7ace7107598469095950cfa649607be92cb0a))
* **tests:** add comprehensive test suite with plenary.nvim ([4a2bce2](https://github.com/shelltime/coding-extension-vim/commit/4a2bce211a1fffe5dc0907020474a2007fc032fd))


### Bug Fixes

* **ci:** add Codecov token for authentication ([fe45f98](https://github.com/shelltime/coding-extension-vim/commit/fe45f98674442ffd97531ff209499520c8136a42))
* **ci:** add project root to package path for test helpers ([a456d32](https://github.com/shelltime/coding-extension-vim/commit/a456d32b47bca827a1171fd7279ab77664593284))
* **ci:** properly initialize luacov for coverage collection ([83db2fd](https://github.com/shelltime/coding-extension-vim/commit/83db2fd04b932ba43a7c79ae521fddddee81696e))
* **config:** resolve stack overflow from recursive config loading ([87fb3cd](https://github.com/shelltime/coding-extension-vim/commit/87fb3cd335847acdb3ba693d94581ddf9ffb6307))
* **heartbeat:** add language fallback detection from file extension ([1d1706c](https://github.com/shelltime/coding-extension-vim/commit/1d1706cef2c214a6f0b8e106ff8f56d4c9d85de1))
* **heartbeat:** add language fallback detection from file extension ([49bc121](https://github.com/shelltime/coding-extension-vim/commit/49bc1217e3237eb4a8eff2ad564e82c1d2e6a483))
* **language:** handle hidden files without extension correctly ([38c3e34](https://github.com/shelltime/coding-extension-vim/commit/38c3e34b40319e4a3a2e7dff108c564d54d23b9e))
* **socket:** use vim.json API for fast event context compatibility ([cd4094b](https://github.com/shelltime/coding-extension-vim/commit/cd4094b8b6d814f12bc1a256cb0f372112f6cdcd))
* **socket:** use vim.json API for fast event context compatibility ([60488b1](https://github.com/shelltime/coding-extension-vim/commit/60488b12514fb7a49240d9fb033e71eac2f9a613))


### Documentation

* **readme,claude:** improve documentation structure and add badges ([bfdfe51](https://github.com/shelltime/coding-extension-vim/commit/bfdfe51ca57cd2f5abf9b8d02a4995b72ec4eb13))
* **readme:** update repository name to shelltime/coding-extension-vim ([9d1810b](https://github.com/shelltime/coding-extension-vim/commit/9d1810b1ffe299d5f2eb9fb3c5ba8304e2873ffb))
