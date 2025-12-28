#!/bin/bash
# Run tests with code coverage using luacov
# Requires: luacov, luacov-reporter-lcov installed via luarocks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Clean previous coverage data
rm -f luacov.stats.out luacov.report.out lcov.info

# Run tests with coverage init (loads luacov before test code)
nvim --headless \
  -u "$PROJECT_DIR/tests/coverage_init.lua" \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/coverage_init.lua'}" \
  2>&1 || true

# Generate lcov report for Codecov
if [ -f luacov.stats.out ]; then
  luacov -r lcov -o lcov.info
  echo "Coverage report generated: lcov.info"
else
  echo "Warning: No coverage stats generated (luacov may not be installed)"
  # Don't fail CI if coverage isn't available
  exit 0
fi
