local config = require("quarkdown.config")

local M = {}

local state = {
  source = nil,
  win = nil,
  bufnr = nil,
  image = nil,
  page = 1,
  pdf_path = nil,
  cache_dir = nil,
  watch_group = nil,
  busy = false,
}

local function inline_options()
  return (config.options.preview and config.options.preview.inline) or {}
end

local function require_image()
  local ok, img = pcall(require, "image")
  if not ok then
    vim.notify(
      "quarkdown.nvim: inline preview requires the 3rd/image.nvim plugin",
      vim.log.levels.ERROR
    )
    return nil
  end
  return img
end

local function require_pdftoppm()
  if vim.fn.executable("pdftoppm") == 1 then
    return true
  end
  vim.notify(
    "quarkdown.nvim: `pdftoppm` (poppler) not found on PATH; install poppler",
    vim.log.levels.ERROR
  )
  return false
end

local function ensure_cache_dir()
  local opts = inline_options()
  local dir = opts.cache_dir
  if not dir or dir == "" then
    dir = vim.fn.stdpath("cache") .. "/quarkdown.nvim"
  end
  vim.fn.mkdir(dir, "p")
  state.cache_dir = dir
  return dir
end

local function quarkdown_executable()
  local cmd = config.options.cmd or { "quarkdown" }
  return cmd[1] or "quarkdown"
end

local function newest_pdf(dir)
  local pdfs = vim.fn.glob(dir .. "/**/*.pdf", false, true)
  if #pdfs == 0 then return nil end
  table.sort(pdfs, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  return pdfs[1]
end

local function compile_pdf(file, on_done)
  if state.busy then return end
  state.busy = true
  local cache = ensure_cache_dir()
  local cmd = {
    quarkdown_executable(),
    "compile",
    "--pdf",
    "--clean",
    "-o", cache,
    file,
  }
  vim.system(cmd, { cwd = vim.fs.dirname(file), text = true }, function(out)
    vim.schedule(function()
      state.busy = false
      if out.code ~= 0 then
        vim.notify(
          ("quarkdown: PDF compile failed (%d)\n%s"):format(out.code, out.stderr or ""),
          vim.log.levels.ERROR
        )
        return
      end
      local pdf = newest_pdf(cache)
      if not pdf then
        vim.notify("quarkdown: no PDF produced (does the doctype support PDF?)", vim.log.levels.ERROR)
        return
      end
      state.pdf_path = pdf
      if on_done then on_done() end
    end)
  end)
end

local function rasterize_page(page, on_done)
  if not state.pdf_path then return end
  local cache = state.cache_dir
  local base = cache .. "/page"
  for _, f in ipairs(vim.fn.glob(base .. "*.png", false, true)) do
    pcall(vim.fn.delete, f)
  end
  local dpi = inline_options().dpi or 144
  local cmd = {
    "pdftoppm",
    "-png",
    "-r", tostring(dpi),
    "-f", tostring(page),
    "-l", tostring(page),
    state.pdf_path,
    base,
  }
  vim.system(cmd, { text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        vim.notify(
          ("quarkdown: pdftoppm failed (%d)\n%s"):format(out.code, out.stderr or ""),
          vim.log.levels.ERROR
        )
        return
      end
      local pngs = vim.fn.glob(base .. "*.png", false, true)
      if #pngs == 0 then
        vim.notify("quarkdown: page " .. page .. " not found in PDF", vim.log.levels.WARN)
        return
      end
      if on_done then on_done(pngs[1]) end
    end)
  end)
end

local function ensure_split()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    return state.win
  end
  local width = inline_options().width or 60
  vim.cmd("botright vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(state.win, width)
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.win, state.bufnr)
  vim.bo[state.bufnr].buftype = "nofile"
  vim.bo[state.bufnr].bufhidden = "wipe"
  vim.bo[state.bufnr].swapfile = false
  pcall(vim.api.nvim_buf_set_name, state.bufnr, "quarkdown://inline-preview")
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].signcolumn = "no"
  vim.wo[state.win].winfixwidth = true
  vim.keymap.set("n", "q", "<cmd>QuarkdownPreviewClose<cr>", { buffer = state.bufnr, nowait = true, silent = true })
  vim.keymap.set("n", "]p", "<cmd>QuarkdownPreviewNext<cr>", { buffer = state.bufnr, silent = true })
  vim.keymap.set("n", "[p", "<cmd>QuarkdownPreviewPrev<cr>", { buffer = state.bufnr, silent = true })
  vim.keymap.set("n", "r", "<cmd>QuarkdownPreviewRefresh<cr>", { buffer = state.bufnr, silent = true })
  return state.win
end

local function show_image(png_path)
  local img = require_image()
  if not img then return end
  if state.image then
    pcall(function() state.image:clear() end)
    state.image = nil
  end
  ensure_split()
  local ok, instance = pcall(img.from_file, png_path, {
    window = state.win,
    buffer = state.bufnr,
    with_virtual_padding = true,
    inline = true,
  })
  if not ok or not instance then
    vim.notify("quarkdown: image.nvim failed to load preview", vim.log.levels.ERROR)
    return
  end
  state.image = instance
  pcall(function() state.image:render() end)
end

local function setup_watch(file)
  if not inline_options().refresh_on_save then return end
  if state.watch_group then
    pcall(vim.api.nvim_del_augroup_by_id, state.watch_group)
  end
  state.watch_group = vim.api.nvim_create_augroup("quarkdown.nvim.preview", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = state.watch_group,
    pattern = file,
    callback = function() M.refresh() end,
  })
end

function M.refresh()
  if not state.source then return end
  compile_pdf(state.source, function()
    rasterize_page(state.page, show_image)
  end)
end

function M.start(file)
  if not require_image() then return end
  if not require_pdftoppm() then return end
  state.source = file
  state.page = inline_options().page or 1
  local origin_win = vim.api.nvim_get_current_win()
  ensure_split()
  if vim.api.nvim_win_is_valid(origin_win) then
    vim.api.nvim_set_current_win(origin_win)
  end
  setup_watch(file)
  M.refresh()
end

function M.stop()
  if state.image then
    pcall(function() state.image:clear() end)
    state.image = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
  state.bufnr = nil
  if state.watch_group then
    pcall(vim.api.nvim_del_augroup_by_id, state.watch_group)
    state.watch_group = nil
  end
end

function M.next_page()
  if not state.pdf_path then return end
  state.page = state.page + 1
  rasterize_page(state.page, show_image)
end

function M.prev_page()
  if not state.pdf_path then return end
  state.page = math.max(1, state.page - 1)
  rasterize_page(state.page, show_image)
end

function M.set_page(n)
  if not state.pdf_path then return end
  state.page = math.max(1, tonumber(n) or 1)
  rasterize_page(state.page, show_image)
end

function M.is_active()
  return state.source ~= nil
end

return M
