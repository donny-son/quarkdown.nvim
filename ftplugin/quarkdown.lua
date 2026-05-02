if vim.b.did_ftplugin_quarkdown then
  return
end
vim.b.did_ftplugin_quarkdown = 1

local bo = vim.bo
bo.commentstring = "<!-- %s -->"
bo.suffixesadd = ".qd"
bo.expandtab = true
bo.shiftwidth = 4
bo.softtabstop = 4
bo.tabstop = 4

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
  .. "|setl commentstring< suffixesadd< expandtab< shiftwidth< softtabstop< tabstop<"

require("quarkdown.lsp").attach(vim.api.nvim_get_current_buf())
