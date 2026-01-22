-- Enhanced emoji completion support for markdown files
return {
  {
    "moyiz/blink-emoji.nvim",
    dependencies = {
      "saghen/blink.cmp",
    },
    config = function()
      local blink_emoji = require("blink-emoji")

      -- Configure emoji with specific trigger patterns for markdown files
      blink_emoji.setup({
        insert = true,
        trigger_patterns = {
          -- This pattern will match ":smile" and similar emoji codes
          { pattern = ":%a+", filetype = "markdown" },
        }
      })

      -- Add an autocmd specific for markdown files to enhance emoji completion
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          -- Enable special emoji completion for markdown
          local buffer = vim.api.nvim_get_current_buf()

          -- Add buffer-local keymap for <C-l> to complete emojis when after a colon
          vim.keymap.set("i", "<C-l>", function()
            local line = vim.api.nvim_get_current_line()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local before_cursor = line:sub(1, col)

            -- If we have a colon followed by text, trigger completion
            if before_cursor:match(":%a+$") then
              require("cmp").complete({ reason = require("cmp").ContextReason.Manual })
            else
              -- Otherwise fall back to the standard <C-l>
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-l>", true, true, true), "n", true)
            end
          end, { buffer = buffer, desc = "Complete emoji or trigger completion" })
        end,
      })
    end,
  }
}
