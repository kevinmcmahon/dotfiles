local M = {}

M.is_mac = vim.fn.has("mac") == 1
M.is_linux = vim.fn.has("linux") == 1

return M
