-- bootstrap lazy.nvim, LazyVim and your plugins
vim.g.python3_host_prog = vim.fn.expand("~/.local/share/nvim/venv/bin/python")
require("config.lazy")
