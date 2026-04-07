local cwd = vim.fn.getcwd()
local parser_dir = os.getenv("NVIM_SLIMETREE_PARSER_DIR") or (cwd .. "/tests/pack/vendor/parsers")

vim.opt.runtimepath:append(cwd)
vim.opt.runtimepath:append(cwd .. "/tests/pack/vendor/start/plenary.nvim")
vim.opt.runtimepath:append(cwd .. "/tests/pack/vendor/start/nvim-treesitter")
vim.opt.runtimepath:append(parser_dir)

pcall(function()
  require("nvim-treesitter.configs").setup({
    parser_install_dir = parser_dir,
  })
end)

vim.opt.swapfile = false
vim.opt.hidden = true
