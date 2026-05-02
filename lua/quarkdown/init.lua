local M = {}

function M.setup(opts)
  local options = require("quarkdown.config").setup(opts)
  require("quarkdown.commands").register()

  local group = vim.api.nvim_create_augroup("quarkdown.nvim", { clear = true })
  if options.auto_attach then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "quarkdown",
      callback = function(args)
        require("quarkdown.lsp").attach(args.buf)
      end,
    })
  end

  return options
end

return M
