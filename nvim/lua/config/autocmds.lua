-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--
-- -- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Add emoji completion for markdown files
vim.api.nvim_create_augroup("emoji_completion", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "emoji_completion",
  pattern = "markdown",
  callback = function()
    -- Add special handling for emoji completion in markdown files
    local buffer = vim.api.nvim_get_current_buf()
    vim.keymap.set("i", "<C-l>", function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local before_cursor = line:sub(1, col)

      -- If we have a colon followed by text, trigger completion
      if before_cursor:match(":%a+$") then
        require("cmp").complete()
      else
        -- Otherwise fall back to the standard <C-l>
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-l>", true, true, true), "n", true)
      end
    end, { buffer = buffer, desc = "Complete emoji or trigger completion" })
  end,
})
