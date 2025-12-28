#!/bin/bash
# Run tests for shelltime.nvim
# Requires: plenary.nvim installed in Neovim

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Run all tests
if [ -z "$1" ]; then
  nvim --headless \
    -u "$PROJECT_DIR/tests/minimal_init.lua" \
    -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" \
    2>&1
else
  # Run specific test file
  nvim --headless \
    -u "$PROJECT_DIR/tests/minimal_init.lua" \
    -c "PlenaryBustedFile $1 {minimal_init = 'tests/minimal_init.lua'}" \
    2>&1
fi
