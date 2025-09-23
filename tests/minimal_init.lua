-- Minimal init for running Plenary tests headlessly
-- Set runtimepath to include the plugin and Plenary
local fn = vim.fn

-- Append this repo to rtp
local repo_root = fn.fnamemodify(fn.getcwd(), ":p")
vim.opt.rtp:append(repo_root)

-- Ensure package.path can resolve lua/ modules
local sep = package.config:sub(1,1)
local lua_path = repo_root .. "lua" .. sep .. "?.lua;" .. repo_root .. "lua" .. sep .. "?" .. sep .. "init.lua;"
package.path = lua_path .. package.path

-- Add local pack path for vendored plugins used in tests
local pack_root = repo_root .. "tests" .. sep .. "pack"
vim.opt.packpath:prepend(pack_root)
vim.opt.rtp:append(pack_root .. sep .. "vendor" .. sep .. "start" .. sep .. "plenary.nvim")

-- Disable swapfiles to avoid errors when using unnamed buffers in tests
vim.opt.swapfile = false

-- Silence notifications during tests
vim.notify = vim.notify or function() end

-- Load Plenary if present
pcall(vim.cmd, "runtime! plugin/plenary.vim")
