-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
--
-- -- LSP Server to use for Python.
-- Set to "basedpyright" to use basedpyright instead of pyright.
vim.g.lazyvim_python_lsp = "pyright"
-- Set to "ruff_lsp" to use the old LSP implementation version.
vim.g.lazyvim_python_ruff = "ruff"

vim.opt.iskeyword:remove("_")

vim.opt.smarttab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Enable break indent
vim.opt.breakindent = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.undofile = true

-- Over SSH, use Neovim's built-in OSC 52 provider (Nvim 0.11+). The escape
-- sequence travels through tmux (set-clipboard on) to the local terminal,
-- which writes it to the Mac clipboard. Locally, keep pbcopy/pbpaste.
if vim.env.SSH_CONNECTION then
  vim.g.clipboard = "osc52"
else
  vim.g.clipboard = {
    name = "osc52-pbcopy",
    copy = {
      ["+"] = "pbcopy",
      ["*"] = "pbcopy",
    },
    paste = {
      ["+"] = "pbpaste",
      ["*"] = "pbpaste",
    },
    cache_enabled = 0,
  }
end
