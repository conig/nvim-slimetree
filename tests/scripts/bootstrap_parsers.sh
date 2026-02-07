#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TS_PLUGIN_DIR="$ROOT_DIR/tests/pack/vendor/start/nvim-treesitter"
PARSER_DIR="$ROOT_DIR/tests/pack/vendor/parsers"

mkdir -p "$ROOT_DIR/tests/pack/vendor/start" "$PARSER_DIR"

if [ ! -d "$TS_PLUGIN_DIR/.git" ]; then
  git clone --depth=1 https://github.com/nvim-treesitter/nvim-treesitter "$TS_PLUGIN_DIR"
fi

NVIM_SLIMETREE_PARSER_DIR="$PARSER_DIR" \
  nvim --headless -i NONE -u "$ROOT_DIR/tests/minimal_init.lua" \
    -c "TSInstallSync python bash" \
    -c "qa"
