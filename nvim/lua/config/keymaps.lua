-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
vim.keymap.set("n", "<leader>cf", function()
  require("conform").format({
    lsp_format = "fallback"
  })
end, { desc = "Formats current file" })

vim.keymap.set("n", "-", "<cmd>Oil --float<CR>", { desc = "Open parent directory in Oil" })

-- Toggle copilot completion on <leader>uc
vim.keymap.set("n", "<leader>uc", function()
  vim.g.copilot_completion_enabled = not vim.g.copilot_completion_enabled
  if vim.g.copilot_completion_enabled then
    vim.cmd("Copilot enable")
  else
    vim.cmd("Copilot disable")
  end
end, { desc = "Toggle [C]opilot" })
