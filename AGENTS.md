# Project guide for agents

This Agents.md file provides comprehensive guidance for AI agents working with this codebase.

## Project aim

To have a tree-sitter based REPL-like system for sending commands to a terminal via slime. There are two major components:

1. slimetree, the tree-sitter based REPL-like system
2. gootabs, a system for managing multiple terminals via tmux

Dir struction
```
lua/
└── nvim-slimetree/
    ├── init.lua
    ├── slimetree.lua
    ├── gootabs.lua
    ├── get_nodes.lua
    ├── utils.lua
└── nodes/
    └── R/
        ├── acceptable.lua
        ├── bad_parents.lua
        ├── root.lua
        ├── skip.lua
        └── sub_root.lua
```

## Key modules

### `init.lua`

Entry point for the plugin. Exposes the two main submodules:

- `slimetree`: Manages Tree-sitter node selection and REPL logic.
- `gootabs`: Manages tmux pane/window creation and tracking.

The following global variables are also set:
`_G.goo_started` to false
`_G.use_goo` to true

These enable users to set up autocmds to handle gootabs. For example:

```
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    local Scripts = require "nvim-slimetree"
    -- Check if goo was started
    if _G.goo_started then
      -- Ensure Scripts.end_goo exists and is callable
      if type(Scripts) == "table" and type(Scripts.gootabs.end_goo) == "function" then
        Scripts.gootabs.end_goo()
      else
      end
    end
  end,
  desc = "Trigger Scripts.end_goo when Neovim exits if goo session was started",
})

```

### `slimetree.lua`

Core logic for sending code to `vim-slime`. Responsibilities include:

- Identifying valid code chunks using Tree-sitter nodes.
- Skipping invalid treesitter objects, e.g., comments, or non-executeable markdown chunk lines such as "```"
- Traversing the tree to find the next suitable node.
- Sending code to the REPL with `goo_move()`, which can also move the cursor after execution.

### `get_nodes.lua`

Selects the appropriate Tree-sitter configuration based on the buffer's filetype.

#### acceptable

These chunks of code are acceptable for execution

#### bad parents

If a tressitter class has these parents, consider them unacceptable for execution.
This is useful if a class would normally be OK, but if found within a call, the parent should be given priority. E.g.,
`1` is fine to execute, but in `sum(c(1,2))`, the parent call is more meaningful.

#### root

The root level of the buffer, which is not executeable.

#### skip

Nodes to skip over, e.g., comments, yaml chunks

#### sub_root

These act like non-executeable local roots in a tree, for example code blocks, or bracketed expressions.

### `gootabs.lua`

Manages tmux session and pane logic:

- Creates a dedicated `gooTabs` tmux window with four panes.
- Stores and retrieves pane IDs.
- Moves panes in/out and tears them down as needed.

Variables need to be tracked to ensure neovim can identify whether gootabs has been started, or not.

`_G.goo_started` to false

It is important that initiation of gooTabs is quick, or that it does not block neovim startup

## How it fits together

    `get_nodes.get_nodes()` selects node tables for the current file type.

    `slimetree.goo_move()` uses those tables to analyze the cursor’s Tree‑sitter node, send the appropriate code region to vim‑slime, and optionally reposition the cursor.

    `gootabs.start_goo()` launches tmux panes for REPLs; `summon_goo()` brings a chosen pane into the current window; `end_goo()` shuts down the session.

    `init.lua` exposes both slimetree and gootabs as the public interface.
