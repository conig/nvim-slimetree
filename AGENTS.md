# Project guide for agents

This document is the contributor and implementation spec for `nvim-slimetree`.

## Project intent

`nvim-slimetree` provides fast, deterministic Tree-sitter chunk selection for REPL send workflows in Neovim, with optional tmux helpers.

The plugin has two independent domains:

1. `slimetree`: choose executable chunk under/after cursor and send to configured transport (`tmux_native` or `vim-slime` fallback).
2. `gootabs`: optional tmux pane/window orchestration for multi-REPL workflows.

`slimetree` must work even when `gootabs` is disabled.

## Design principles

1. Deterministic cursor movement and send range selection.
2. Minimal hidden global state.
3. tmux integration is opt-in and non-blocking.
4. Public API stability through explicit deprecation shims.
5. Behavior locked by project-owned tests under `tests/spec`.

## Repository structure

```text
lua/
  nvim-slimetree/
    init.lua
    config.lua
    state.lua
    slimetree.lua
    gootabs.lua
    get_nodes.lua
    utils.lua
    core/
      lang.lua
      selector.lua
      cursor.lua
      transport/
        init.lua
        tmux_native.lua
        slime.lua
  nodes/
    R/
    python/
    bash/
tests/
  minimal_init.lua
  scripts/
  spec/
```

## Runtime architecture

### `init.lua`

Public plugin entrypoint.

Responsibilities:

1. Expose submodules `slimetree` and `gootabs`.
2. Provide `setup(opts)` to normalize and apply config.
3. Keep compatibility globals in sync:
   - `_G.goo_started`
   - `_G.use_goo`
4. Provide `get_state()` as a deep-copied runtime snapshot for diagnostics/tests.

### `config.lua`

Defines defaults and configuration normalization.

Config keys:

- `repl.require_gootabs` (default `false`)
- `transport.backend` (`auto|tmux_native|slime`, default `auto`)
- `transport.async` (default `true`)
- `transport.mode` (`control|exec`, default `control`)
- `transport.max_queue` (default `256`)
- `transport.fallback_to_slime` (default `true`)
- `transport.tmux.buffer_name` (default `"slimetree_send"`)
- `transport.tmux.cancel_copy_mode` (default `true`)
- `transport.tmux.bracketed_paste` (`auto|true|false`, default `auto`)
- `transport.tmux.append_newline` (default `true`)
- `transport.tmux.enter_mode` (`auto|always|never`, default `auto`)
- `cursor.move_after_send` (default `true`)
- `cursor.default_col` (default `0`)
- `gootabs.enabled` (default `false`)
- `gootabs.auto_start` (default `false`)
- `gootabs.window_name` (default `"gooTabs"`)
- `gootabs.layout` (`none|single|grid4|custom`, default `grid4`)
- `gootabs.pane_count`
- `gootabs.pane_commands`
- `gootabs.join_on_select`
- `gootabs.join_size`
- `gootabs.reset_layout_on_return`
- `notify.silent`
- `notify.level`
- `language_aliases` (filetype -> node-spec language folder)

### `state.lua`

Single source of runtime state.

Tracks:

- active normalized config
- gootabs lifecycle state (`started`, pane ids, window name, active target)
- transport runtime state (queue, running/connected flags, last error, counters)

### `core/lang.lua`

Resolves a filetype to node-spec tables and validates schema.

Required schema keys:

- `acceptable`
- `skip`
- `root`
- `sub_roots`
- `bad_parents`

If unsupported or invalid, returns typed errors.

### `core/selector.lua`

Deterministic Tree-sitter selection engine.

Responsibilities:

1. skip/acceptable/root evaluation
2. bad-parent rejection
3. smallest acceptable ancestor resolution
4. next acceptable node traversal
5. `select_range(bufnr, cursor, spec)` result object

Result contract:

- success: `{ ok=true, start_row, end_row, node_type, ... }`
- failure: `{ ok=false, reason=<typed_reason> }`

### `core/cursor.lua`

Pure cursor policy from send range -> next position.

### `slimetree.lua`

Public REPL send API.

Primary APIs:

- `send_current(opts?)`
- `send_line()`
- `transport_status()`
- `transport_restart()`
- `goo_send(text)` (legacy direct-send helper; prefer `send_current`/`send_line` for chunk-aware behavior)

Compatibility shims:

- `goo_move(hold_position)` -> `send_current`
- `SlimeCurrentLine()` -> `send_line`

`send_current` must return structured status and never assume tmux unless configured.

### `gootabs.lua`

Optional tmux integration.

Primary APIs:

- `start(opts?)`
- `select(index, opts?)`
- `stop(opts?)`
- `status()`

Compatibility shims:

- `start_goo`
- `summon_goo`
- `end_goo`

Default behavior is opt-in (`gootabs.enabled=false`).

## Node spec conventions

Node lists are set-like tables with `true` values.

1. `acceptable`: executable units.
2. `skip`: non-executable nodes (comments, markdown fences, etc.).
3. `root`: parser root node type.
4. `sub_roots`: local roots where bad-parent traversal should stop.
5. `bad_parents`: parents that invalidate a normally acceptable leaf.

## Test policy

Project behavior is defined by tests in `tests/spec`.

Minimum required coverage:

1. cursor movement policy (`core/cursor.lua`)
2. selector acceptance and traversal (`core/selector.lua`)
3. filetype resolution and unsupported behavior (`core/lang.lua`)
4. parser-backed selection behavior for Python and Bash specs

Do not treat vendored `plenary.nvim` tests as project behavior coverage.

Run tests with:

```bash
tests/scripts/bootstrap_parsers.sh
nvim --headless -i NONE -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua' }" -c qa
```

`tests/scripts/bootstrap_parsers.sh` installs test parser dependencies (`nvim-treesitter`, `python`, and `bash`) into repo-local test paths.

## Performance constraints

1. Avoid full-buffer scans for each send action.
2. Avoid repeated parser invalidation except when parser is stale.
3. Keep selector traversal bounded to cursor-forward source order.

## Backward compatibility and migration

1. Existing function names remain available through shims.
2. New integrations should call non-legacy APIs and `setup(opts)`.
3. Compatibility globals are shimmed for user autocmds, but module-local state is authoritative.

## Safe change checklist

When editing core behavior:

1. Update selector/cursor tests first or in same change.
2. Keep `reason` codes stable or document migration.
3. Preserve no-tmux default behavior.
4. Update `README.md` and this file when public APIs/config change.
