# nvim-slimetree

> [!IMPORTANT]
> This plugin is in infancy and I'm going to change a lot of things. So expect things to break.

nvim-slimetree has two main features:

1. Intelligent Treesitter based code exection in a REPL
2. Management of multiple REPLs via tmux

The objective of nvim-slimetree is to allow chunks of complete code to be executed based on cursor position and the treesitter syntax tree.
By doing so, users can swiftly jump through their codebase, without having to manually select whether lines or paragraphs of code should be executed.

## Code execution

I built this package to support my own workflow, which revolves around R. Accordingly, as far as I am aware the code execution will work perfectly for R. However, there is also some support for lua.

All languages can be supported, however it requires a list of acceptable node types to be assembled for each language.

This is something I plan to do, as I need it, so feel free to do a PR or fork the library to add support for your language.

## Testing

This repo uses plenary.nvim’s busted harness to run headless tests.

- Run all tests:
  - `./scripts/test.sh` (or `make test`)

Notes:
- The script vendors `plenary.nvim` into `tests/pack/vendor/start` on first run.
- Tests run Neovim headless with a minimal init at `tests/minimal_init.lua`.
- External integrations are stubbed:
  - tmux commands are mocked in gootabs tests; tmux is not required.
  - We avoid loading your user config and only run tests in `tests/`.

## REPL management

Something I miss from vscode is having multiple terminals which you can switch between.

I have implemented a hacky tmux solution to achieve this. You must have tmux active in your terminal for this to work.

The following keybindings are available to facilitate this.

Execute Start goo to initiate the window "gooTabs"

Then, to summon each of four terminals execute summon_goo(n), where n is the terminal you wish to retrieve.
This will bring that terminal pane into your session, it will be returned to its origin when you summon another terminal.

```{lua}

local st = require("nvim-slimetree")

vim.keymap.set("n", "<leader>gs", function()
    st.gootabs.start_goo "clear && r"
end, { desc = "Start goo", noremap = true, silent = true })

vim.keymap.set("n", "<leader>g1", function()
    st.gootabs.summon_goo(1)
end, { desc = "Summon goo 1", noremap = true, silent = true })

vim.keymap.set("n", "<leader>g2", function()
    st.gootabs.summon_goo(2)
end, { desc = "Summon goo 2", noremap = true, silent = true })

vim.keymap.set("n", "<leader>g3", function()
    st.gootabs.summon_goo(3)
end, { desc = "Summon goo 3", noremap = true, silent = true })

vim.keymap.set("n", "<leader>g4", function()
    st.gootabs.summon_goo(4)
end, { desc = "Summon goo 4", noremap = true, silent = true })
```

## Example installation and configuration

```{lua}

return {
{
    "conig/nvim-slimetree",
    ft = { "r", "rmd", "quarto", "lua" },
    dependencies = "jpalardy/vim-slime",
    config = function()
      local st = require "nvim-slimetree"

      -- Keymaps for .slimetree
      vim.keymap.set("x", "<CR>", "<Plug>SlimeRegionSend", { remap = true, silent = true })
      vim.keymap.set("n", "<CR>", function()
        st.slimetree.goo_move()
      end, { desc = "Slime and move" })
      vim.keymap.set("n", "<leader><CR>", function()
        st.slimetree.goo_move(true)
      end, { desc = "Slime and hold position", noremap = true })
      vim.keymap.set("n", "<C-c><C-c>", function()
        st.slimetree.SlimeCurrentLine()
      end, { desc = "Send current line to Slime" })

      -- Keymaps for .gootabs
      vim.keymap.set("n", "<leader>gs", function()
        st.gootabs.start_goo "clear && r"
      end, { desc = "Start goo", noremap = true, silent = true })
      vim.keymap.set("n", "<leader>g1", function()
        st.gootabs.summon_goo(1)
      end, { desc = "Summon goo 1", noremap = true, silent = true })
      vim.keymap.set("n", "<leader>g2", function()
        st.gootabs.summon_goo(2)
      end, { desc = "Summon goo 2", noremap = true, silent = true })
      vim.keymap.set("n", "<leader>g3", function()
        st.gootabs.summon_goo(3)
      end, { desc = "Summon goo 3", noremap = true, silent = true })
      vim.keymap.set("n", "<leader>g4", function()
        st.gootabs.summon_goo(4)
      end, { desc = "Summon goo 4", noremap = true, silent = true })
    end,
  }}

```
