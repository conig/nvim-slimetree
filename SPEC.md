# Terminal Transport Support

## Goal

Add a native Neovim terminal transport to `nvim-slimetree` so managed terminal sessions can receive chunk sends without going through `vim-slime`, while preserving the existing native tmux path and generic slime fallback.

## Constraints

- Keep tmux first-class.
- Keep the existing public send API unchanged.
- Do not add terminal lifecycle management to `nvim-slimetree`.
- Do not regress current `vim-slime` fallback behavior.

## Design

### Backend selection

- Extend `transport.backend` to accept `terminal`.
- In `auto` mode, resolve backends in this order:
  1. `tmux_native` when a tmux target is configured
  2. `terminal` when a managed Neovim terminal target is configured
  3. `slime` fallback otherwise

This keeps tmux preferred whenever both target types are available.

### Terminal target contract

Add a repo-owned managed terminal target shape:

```lua
vim.g.slimetree_terminal_config = {
  bufnr = 12, -- optional if jobid is provided
  jobid = 34, -- optional if bufnr resolves to a terminal channel
}
```

Supported scopes:

- `b:slimetree_terminal_config`
- `g:slimetree_terminal_config`

For interoperability, the native terminal backend may also reuse:

- `b:slime_config`
- `g:slime_default_config`

but only when `slime_target` resolves to `neovim`.

### Send semantics

- Terminal sends are synchronous and queue-free.
- Accept either `jobid` or `bufnr`; derive the missing value when possible.
- Validate that any supplied buffer is a terminal buffer.
- Support optional bracketed paste and newline append behavior under `transport.terminal`.

## Non-goals

- No terminal window creation or management helpers.
- No changes to `gootabs`.
- No attempt to replace `vim-slime` for non-tmux, non-terminal targets.

## Verification

- Config normalization tests for the new backend and terminal defaults.
- Backend resolution tests covering tmux preference and terminal fallback.
- Focused transport tests for terminal target resolution and send behavior.
