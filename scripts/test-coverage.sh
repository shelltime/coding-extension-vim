#!/bin/bash
# Run tests with code coverage using luacov
# Requires: luacov, luacov-reporter-lcov installed via luarocks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Clean previous coverage data
rm -f luacov.stats.out luacov.report.out lcov.info

# Run tests with luacov
nvim --headless \
  -u "$PROJECT_DIR/tests/minimal_init.lua" \
  -c "lua require('luacov')" \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" \
  2>&1

# Generate lcov report for Codecov
if [ -f luacov.stats.out ]; then
  luacov -r lcov -o lcov.info
  echo "Coverage report generated: lcov.info"
else
  echo "Warning: No coverage stats generated"
  exit 1
fi
