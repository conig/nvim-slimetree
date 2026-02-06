# nvim-slimetree

`nvim-slimetree` is a Tree-sitter-driven REPL send plugin for Neovim.

It has two features:

1. Deterministic chunk execution (`slimetree`)
2. Optional tmux pane management (`gootabs`)

## Defaults

- tmux/gootabs is **off** by default.
- REPL send works with `vim-slime` without creating extra panes.

## Installation

```lua
return {
  {
    "conig/nvim-slimetree",
    ft = { "r", "rmd", "qmd", "quarto", "python" },
    dependencies = { "jpalardy/vim-slime" },
    config = function()
      local st = require("nvim-slimetree")

      st.setup({
        gootabs = {
          enabled = false,
        },
      })

      vim.keymap.set("x", "<CR>", "<Plug>SlimeRegionSend", { remap = true, silent = true })
      vim.keymap.set("n", "<CR>", function()
        st.slimetree.send_current()
      end, { desc = "Send chunk and move" })
      vim.keymap.set("n", "<leader><CR>", function()
        st.slimetree.send_current({ hold_position = true })
      end, { desc = "Send chunk and hold" })
      vim.keymap.set("n", "<C-c><C-c>", function()
        st.slimetree.send_line()
      end, { desc = "Send current line" })
    end,
  },
}
```

## Optional gootabs (tmux)

Enable explicitly:

```lua
local st = require("nvim-slimetree")

st.setup({
  gootabs = {
    enabled = true,
    layout = "grid4",
    pane_commands = { "R", "python", "bash", "" },
  },
})

vim.keymap.set("n", "<leader>gs", function()
  st.gootabs.start()
end)

vim.keymap.set("n", "<leader>g1", function()
  st.gootabs.select(1)
end)
```

## Public API

- `require("nvim-slimetree").setup(opts)`
- `st.slimetree.send_current(opts?)`
- `st.slimetree.send_line()`
- `st.gootabs.start(opts?)`
- `st.gootabs.select(index, opts?)`
- `st.gootabs.stop(opts?)`
- `st.gootabs.status()`

## Deprecated (still shimmed)

- `slimetree.goo_move`
- `slimetree.SlimeCurrentLine`
- `gootabs.start_goo`
- `gootabs.summon_goo`
- `gootabs.end_goo`

## Tests

```bash
nvim --headless -i NONE -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua' }" -c qa
```
