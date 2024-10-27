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

## REPL management

Something I miss from vscode is having multiple terminals which you can switch between.

I have implemented a hacky tmux solution to achieve this. You must have tmux active in your terminal for this to work.

The following keybindings are available to facilitate this.

Execute Start goo to initiate the window "gooTabs"

Then, to summon each of four terminals execute summon_goo(n), where n is the terminal you wish to retrieve.
This will bring that terminal pane into your session, it will be returned to its origin when you summon another terminal.

```{lua}
    keys = {
      { "<leader>gs", function() require("nvim-slimetree").start_goo("r") end, desc = "Start goo", noremap = true, silent = true },
      { "<leader>g1", function() require("nvim-slimetree").summon_goo(1) end, desc = "Summon goo 1", noremap = true, silent = true },
      { "<leader>g2", function() require("nvim-slimetree").summon_goo(2) end, desc = "Summon goo 2", noremap = true, silent = true },
      { "<leader>g3", function() require("nvim-slimetree").summon_goo(3) end, desc = "Summon goo 3", noremap = true, silent = true },
      { "<leader>g4", function() require("nvim-slimetree").summon_goo(4) end, desc = "Summon goo 4", noremap = true, silent = true },
    }
```
## Example installation and configuration


```{lua}

return {
  {
    "jpalardy/vim-slime",
    ft = { "python", "lua", "zsh", "bash", "rmd", "r", "quarto" },
    config = function()
      -- Configure vim-slime settings here
      vim.g.slime_no_mappings = 1
      vim.g.slime_target = "tmux"
      vim.g.slime_default_config = {
        socket_name = "default",
        target_pane = 1,
      }
      vim.g.slime_dont_ask_default = 1
      vim.g.slime_bracketed_paste = 1 -- Optional: enable bracketed-paste
    end,
  },
  {
    "conig/nvim-slimetree",
    ft = { "markdown", "r", "rmd", "quarto", "lua" },
    dependencies = "jpalardy/vim-slime",
    dev = true,
    dir = "/home/conig/repos/nvim-slimetree/",
    keys = {
      -- Slime key mappings
      { "<CR>", "<Plug>SlimeRegionSend", mode = "x", remap = true, silent = true },
      { "<CR>", function() require("nvim-slimetree").goo_move() end, desc = "Slime and move" },
      { "<C-c><C-c>", function() require("nvim-slimetree").SlimeCurrentLine() end, desc = "Send current line to Slime" },
      { "<leader>gs", function() require("nvim-slimetree").start_goo("r") end, desc = "Start goo", noremap = true, silent = true },
      { "<leader>g1", function() require("nvim-slimetree").summon_goo(1) end, desc = "Summon goo 1", noremap = true, silent = true },
      { "<leader>g2", function() require("nvim-slimetree").summon_goo(2) end, desc = "Summon goo 2", noremap = true, silent = true },
      { "<leader>g3", function() require("nvim-slimetree").summon_goo(3) end, desc = "Summon goo 3", noremap = true, silent = true },
      { "<leader>g4", function() require("nvim-slimetree").summon_goo(4) end, desc = "Summon goo 4", noremap = true, silent = true },
   },
}

```
