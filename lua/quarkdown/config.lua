local M = {}

M.defaults = {
  cmd = { "quarkdown", "language-server" },
  auto_attach = true,
  root_markers = { ".git", "main.qd", "quarkdown.json" },
  capabilities = nil,
  on_attach = nil,
  settings = {},
  semantic_tokens = true,
  compile = {
    args = {},
    output = nil,
    pdf = false,
    preview = true,
    watch = true,
    terminal_height = 10,
  },
  preview = {
    mode = "browser",        -- "browser" (Quarkdown opens a browser tab) or
                             -- "inline" (renders the PDF in a vsplit via image.nvim)
    inline = {
      width = 60,            -- columns of the vertical split
      dpi = 144,             -- pdftoppm rasterization DPI
      page = 1,              -- starting page
      refresh_on_save = true,
      cache_dir = nil,       -- defaults to stdpath("cache") .. "/quarkdown.nvim"
    },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
