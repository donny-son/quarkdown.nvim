local config = require("quarkdown.config")

local M = {}

local function find_root(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == "" then
    return vim.loop.cwd()
  end
  local markers = config.options.root_markers or {}
  if #markers == 0 then
    return vim.fs.dirname(fname)
  end
  local found = vim.fs.find(markers, { upward = true, path = vim.fs.dirname(fname) })[1]
  if found then
    return vim.fs.dirname(found)
  end
  return vim.fs.dirname(fname)
end

local function build_capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  if config.options.capabilities then
    caps = vim.tbl_deep_extend("force", caps, config.options.capabilities)
  end
  return caps
end

local function executable_ok(cmd)
  if type(cmd) ~= "table" or vim.tbl_isempty(cmd) then
    return false, "quarkdown.nvim: invalid `cmd` configuration"
  end
  if vim.fn.executable(cmd[1]) ~= 1 then
    return false, ("quarkdown.nvim: %q not found on PATH"):format(cmd[1])
  end
  return true
end

function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not config.options.auto_attach then
    return
  end
  if vim.bo[bufnr].filetype ~= "quarkdown" then
    return
  end

  local ok, err = executable_ok(config.options.cmd)
  if not ok then
    vim.notify_once(err, vim.log.levels.WARN)
    return
  end

  local root = find_root(bufnr)
  local client_id = vim.lsp.start({
    name = "quarkdown",
    cmd = config.options.cmd,
    root_dir = root,
    capabilities = build_capabilities(),
    settings = config.options.settings,
    on_attach = function(client, buf)
      if config.options.semantic_tokens == false and client.server_capabilities then
        client.server_capabilities.semanticTokensProvider = nil
      end
      if type(config.options.on_attach) == "function" then
        config.options.on_attach(client, buf)
      end
    end,
  })
  return client_id
end

function M.stop()
  for _, client in ipairs(vim.lsp.get_clients({ name = "quarkdown" })) do
    client.stop()
  end
end

function M.restart()
  M.stop()
  vim.defer_fn(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "quarkdown" then
        M.attach(buf)
      end
    end
  end, 200)
end

return M
