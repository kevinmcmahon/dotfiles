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

-- Remote-only: copy yanks to local clipboard via OSC52-compatible pbcopy wrapper
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

-- Yank-to-local-clipboard (OSC52 via pbcopy) for SSH/tmux-only servers.
-- This mimics the "Mac default" feel: yanks go to system clipboard too.
local function copy_to_system_clipboard()
  -- Only on SSH/tmux (adjust if you want it always-on)
  if vim.env.SSH_CONNECTION == nil and vim.env.TMUX == nil then
    return
  end

  -- Only for yank operations
  if vim.v.event.operator ~= "y" then
    return
  end

  -- Get the yanked text from the unnamed register
  local regtype = vim.fn.getregtype('"')
  local lines = vim.fn.getreg('"', 1, true) -- list of lines
  if not lines or #lines == 0 then
    return
  end

  local text = table.concat(lines, "\n")
  -- Preserve linewise yanks with trailing newline (helps match expected paste)
  if regtype:sub(1, 1) == "V" then
    text = text .. "\n"
  end

  -- Send to pbcopy (your OSC52 wrapper)
  vim.fn.jobstart({ "pbcopy" }, { stdin = text, detach = true })
end

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = copy_to_system_clipboard,
})
