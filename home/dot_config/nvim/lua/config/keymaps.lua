-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 从 terminal模式 到 normal模式
vim.keymap.set("t", "jj", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
-- 从 insert模式 到 normal模式
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
