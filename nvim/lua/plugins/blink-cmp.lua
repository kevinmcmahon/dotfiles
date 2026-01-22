return {
  -- Disable the problematic blink-emoji plugin
  { "moyiz/blink-emoji.nvim", enabled = false },

  -- Configure nvim-cmp with emoji support
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-emoji", -- Add emoji source
    },
    opts = function(_, opts)
      local cmp = require("cmp")

      -- Add emoji to sources if not already present
      opts.sources = opts.sources or {}
      table.insert(opts.sources, {
        name = "emoji",
        priority = 1000, -- Give emojis high priority
        group_index = 1  -- Show emoji group first
      })

      local original_mapping = opts.mapping and opts.mapping["<C-l>"] or cmp.mapping.complete()

      opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
        ["<C-l>"] = function(fallback)
          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]
          local before_cursor = line:sub(1, col)

          if before_cursor:match(":%a+$") then
            return cmp.complete({
              config = {
                sources = {
                  { name = "emoji" }
                }
              }
            })
          end

          if type(original_mapping) == "function" then
            return original_mapping(fallback)
          else
            return fallback()
          end
        end,

        -- ✅ Add these mappings for standard autocomplete acceptance
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
      })

      -- Add special configuration for markdown files
      if not opts.filetype_options then
        opts.filetype_options = {}
      end

      opts.filetype_options.markdown = {
        sources = cmp.config.sources({
          { name = "emoji", priority = 1000 },
          { name = "buffer" },
          { name = "path" },
        })
      }

      return opts
    end,
  },

  -- Add autocmd for enhancing emoji completion in markdown files
  {
    "nvim-lua/plenary.nvim",
    optional = true,
    config = function()
      local emoji_group = vim.api.nvim_create_augroup("emoji_completion", { clear = true })

      vim.api.nvim_create_autocmd("FileType", {
        group = emoji_group,
        pattern = "markdown",
        callback = function()
          vim.b.emoji_completion_triggers = {
            ":%a+$"
          }

          local buffer = vim.api.nvim_get_current_buf()
          vim.opt_local.iskeyword:append(":")

          if require("cmp").visible() == 0 then
            require("cmp").setup.buffer({
              completion = {
                keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\|:[a-zA-Z0-9_+-]*\)]]
              },
            })
          end
        end
      })
    end
  }
}
