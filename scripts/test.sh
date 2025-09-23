#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_DIR="$ROOT_DIR/tests/pack/vendor/start"
PLENARY_DIR="$PACK_DIR/plenary.nvim"

if [[ ! -d "$PLENARY_DIR" ]]; then
  echo "[test] Installing plenary.nvim into tests/pack/vendor/start..."
  mkdir -p "$PACK_DIR"
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$PLENARY_DIR"
fi

echo "[test] Running tests with Neovim headless..."
mapfile -t SPECS < <(find "$ROOT_DIR/tests" -type f -name '*_spec.lua' \
  -not -path "$ROOT_DIR/tests/pack/*" | sort)
FAIL=0
for spec in "${SPECS[@]}"; do
  echo "[test] File: ${spec//$ROOT_DIR\//}"
  if ! nvim --headless --noplugin -u "$ROOT_DIR/tests/minimal_init.lua" \
    +"lua require('plenary.busted').run('$spec')" +qa; then
    FAIL=1
  fi
done

exit $FAIL
