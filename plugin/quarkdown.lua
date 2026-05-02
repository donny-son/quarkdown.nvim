if vim.g.loaded_quarkdown_nvim == 1 then
  return
end
vim.g.loaded_quarkdown_nvim = 1

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("quarkdown.nvim requires Neovim 0.10 or newer", vim.log.levels.ERROR)
  return
end

require("quarkdown.commands").register()

local group = vim.api.nvim_create_augroup("quarkdown.nvim.autostart", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "quarkdown",
  callback = function(args)
    if require("quarkdown.config").options.auto_attach then
      require("quarkdown.lsp").attach(args.buf)
    end
  end,
})
