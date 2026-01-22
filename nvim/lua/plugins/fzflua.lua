return {
  "ibhagwan/fzf-lua",
  dependencies = { "echasnovski/mini.icons" },
  opts = {},
  keys = {
    {
      "<leader>ff",
      function() require('fzf-lua').files() end,
      desc = "[F]ind [f]iles"
    },
    {
      "<leader>fg",
      function() require('fzf-lua').live_grep() end,
      desc = "Find by grepping in directory"
    },
    {
      "<leader>fc",
      function() require('fzf-lua').files({ cwd = vim.fn.stdpath("config") }) end,
      desc = "Find in neovim configuration"
    },
    {
      "<leader>fh",
      function() require('fzf-lua').helptags() end,
      desc = "[F]ind [h]elp"
    },
    {
      "<leader>fb",
      function() require('fzf-lua').buffers() end,
      desc = "[F]ind [b]uffers"
    },
    {
      "<leader>fk",
      function() require('fzf-lua').keymaps() end,
      desc = "[F]ind [k]eymaps"
    },
    {
      "<leader>/",
      function() require('fzf-lua').lgrep_curbuf() end,
      desc = "[/] Live grep (current buffer)"
    }
  },
}
